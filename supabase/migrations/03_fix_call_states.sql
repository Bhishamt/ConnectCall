-- Migration: 03_fix_call_states.sql
-- Description: Adds missing call status values to the call_sessions constraint,
--              fixes presence staleness, and improves performance indexes.

-- 1. Drop old CHECK constraint and recreate with all valid status values
--    (PostgreSQL requires dropping the constraint by name)
ALTER TABLE public.call_sessions
    DROP CONSTRAINT IF EXISTS call_sessions_status_check;

ALTER TABLE public.call_sessions
    ADD CONSTRAINT call_sessions_status_check
    CHECK (status IN (
        'idle',
        'calling',
        'ringing',
        'connecting',
        'connected',
        'inCall',
        'ending',
        'ended',
        'rejected',
        'missed',
        'busy',
        'failed',
        'disconnected'
    ));

-- 2. Reset any stale is_online flags (users online > 10 minutes ago are stale)
UPDATE public.profiles
SET is_online = FALSE
WHERE is_online = TRUE
  AND last_seen < NOW() - INTERVAL '10 minutes';

-- 3. Add index on last_seen for efficient stale-presence queries
CREATE INDEX IF NOT EXISTS idx_profiles_last_seen ON public.profiles(last_seen DESC);

-- 4. Add answered_at column index for duration computation
CREATE INDEX IF NOT EXISTS idx_call_sessions_answered_at ON public.call_sessions(answered_at);

-- 5. Add index to efficiently query active calls for a callee
CREATE INDEX IF NOT EXISTS idx_call_sessions_callee_status
    ON public.call_sessions(callee_id, status)
    WHERE status IN ('calling', 'ringing');
