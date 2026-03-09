-- =============================================================================
-- FIX RLS FOR ADDRESSES (DEVELOPMENT MODE)
-- =============================================================================
-- The default RLS policies require a real authenticated user (auth.uid()).
-- Since the app uses a "Demo/Forced ID" mode for testing without SMS login,
-- we need to relax the RLS policies to allow operations on the 'user_addresses' table
-- even if the user is not technically logged in via Supabase Auth.

-- Enable RLS (Ensure it's on)
ALTER TABLE public.user_addresses ENABLE ROW LEVEL SECURITY;

-- Drop existing strict policies
DROP POLICY IF EXISTS "Users can view own addresses" ON public.user_addresses;
DROP POLICY IF EXISTS "Users can insert own addresses" ON public.user_addresses;
DROP POLICY IF EXISTS "Users can update own addresses" ON public.user_addresses;
DROP POLICY IF EXISTS "Users can delete own addresses" ON public.user_addresses;

-- Create permissive policies for Development/Demo
-- WARNING: This allows any client to modify addresses if they know the UUID.
-- Ideally, use a more secure method for production.

CREATE POLICY "Allow all operations for everyone"
ON public.user_addresses
FOR ALL
USING (true)
WITH CHECK (true);

-- Ensure permission is granted to anon role
GRANT ALL ON TABLE public.user_addresses TO anon;
GRANT ALL ON TABLE public.user_addresses TO authenticated;
GRANT ALL ON TABLE public.user_addresses TO service_role;
