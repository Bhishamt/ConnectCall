-- Migration: 02_fix_profiles_rls.sql
-- Description: Ensures automatic profile creation via Postgres trigger on auth.users and verifies strict RLS policies on public.profiles

-- 1. Ensure profiles table and RLS configuration
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 2. Profiles RLS Policies (Minimum Required Permissions)
-- Authenticated users can view all user profiles (needed for contacts, search, & calling)
DROP POLICY IF EXISTS "Authenticated users can view profiles" ON public.profiles;
CREATE POLICY "Authenticated users can view profiles" 
ON public.profiles FOR SELECT 
TO authenticated 
USING (true);

-- Authenticated users can update ONLY their own profile row
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile" 
ON public.profiles FOR UPDATE 
TO authenticated 
USING (auth.uid() = id);

-- Authenticated users can insert ONLY their own profile row (if client insert is ever used)
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
CREATE POLICY "Users can insert own profile" 
ON public.profiles FOR INSERT 
TO authenticated 
WITH CHECK (auth.uid() = id);

-- 3. Automatic Profile Creation Trigger (Security Definer)
-- Trigger runs in administrative context, safely creating profile rows upon signup without exposing client RLS
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, name, email, avatar_url, is_online, created_at, updated_at)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
        NEW.email,
        NEW.raw_user_meta_data->>'avatar_url',
        TRUE,
        NOW(),
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        name = EXCLUDED.name,
        email = EXCLUDED.email,
        updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Re-attach trigger to auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
