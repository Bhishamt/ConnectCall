-- Migration: 04_atomic_call_rpc.sql
-- Description: Provides database-authoritative atomic call initiation function.
--              Prevents simultaneous call race conditions, busy collisions,
--              and orphaned multi-calls by acquiring row-level locks on profiles.

CREATE OR REPLACE FUNCTION public.start_call_atomic(
    p_call_id UUID,
    p_callee_id UUID,
    p_call_type TEXT
)
RETURNS TEXT AS $$
DECLARE
    v_caller_id UUID;
    v_caller_busy BOOLEAN;
    v_callee_busy BOOLEAN;
    v_callee_exists BOOLEAN;
BEGIN
    -- 1. Identify authenticated caller
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RETURN 'UNAUTHENTICATED';
    END IF;

    IF v_caller_id = p_callee_id THEN
        RETURN 'CANNOT_CALL_SELF';
    END IF;

    -- 2. Verify callee exists
    SELECT EXISTS (
        SELECT 1 FROM public.profiles WHERE id = p_callee_id
    ) INTO v_callee_exists;

    IF NOT v_callee_exists THEN
        RETURN 'USER_NOT_FOUND';
    END IF;

    -- 3. Acquire deterministic row locks in sorted order of UUIDs
    --    This guarantees that simultaneous calls between User A and User B cannot deadlock
    --    or create competing active call sessions.
    PERFORM id 
    FROM public.profiles 
    WHERE id IN (v_caller_id, p_callee_id) 
    ORDER BY id 
    FOR UPDATE;

    -- 4. Check if caller is already in an active call
    SELECT EXISTS (
        SELECT 1 FROM public.call_sessions
        WHERE (caller_id = v_caller_id OR callee_id = v_caller_id)
          AND status IN ('calling', 'ringing', 'connecting', 'connected', 'inCall')
    ) INTO v_caller_busy;

    IF v_caller_busy THEN
        RETURN 'ALREADY_IN_CALL';
    END IF;

    -- 5. Check if callee is already in an active call
    SELECT EXISTS (
        SELECT 1 FROM public.call_sessions
        WHERE (caller_id = p_callee_id OR callee_id = p_callee_id)
          AND status IN ('calling', 'ringing', 'connecting', 'connected', 'inCall')
    ) INTO v_callee_busy;

    IF v_callee_busy THEN
        RETURN 'BUSY';
    END IF;

    -- 6. Insert new call session atomically
    INSERT INTO public.call_sessions (
        id,
        caller_id,
        callee_id,
        call_type,
        direction,
        status,
        started_at,
        created_at
    ) VALUES (
        p_call_id,
        v_caller_id,
        p_callee_id,
        p_call_type,
        'outgoing',
        'calling',
        NOW(),
        NOW()
    );

    RETURN 'SUCCESS';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execution permission to authenticated users
GRANT EXECUTE ON FUNCTION public.start_call_atomic(UUID, UUID, TEXT) TO authenticated;
