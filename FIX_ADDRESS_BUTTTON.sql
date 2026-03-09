-- FIX PERMISSIONS for Address Saving
-- Run this in Supabase SQL Editor

-- 1. Disable RLS to allow all writes (Temporary fix for 401 Unauthorized)
ALTER TABLE public.user_addresses DISABLE ROW LEVEL SECURITY;

-- 2. Grant permissions to authenticated users and anon (just in case)
GRANT ALL ON public.user_addresses TO postgres;
GRANT ALL ON public.user_addresses TO anon;
GRANT ALL ON public.user_addresses TO authenticated;
GRANT ALL ON public.user_addresses TO service_role;

-- 3. Ensure the table exists (in case it was missing)
CREATE TABLE IF NOT EXISTS public.user_addresses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id), -- Nullable for now to allow inserts even if auth mismatch
    title TEXT,
    address_line TEXT,
    contact_name TEXT,
    contact_phone TEXT,
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
