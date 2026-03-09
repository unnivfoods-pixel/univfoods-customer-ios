-- FIX LOGIN SYNC ISSUES AND MISSING PROFILES
-- Run this in Supabase SQL Editor to fix "Guest Mode" after login
-- ================================================================

-- 1. FIX CUSTOMER_PROFILES RLS
-- Allows the app (using anon key) to create and read profiles based on phone number
ALTER TABLE public.customer_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.customer_profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.customer_profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.customer_profiles;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.customer_profiles;
DROP POLICY IF EXISTS "Enable insert for all users" ON public.customer_profiles;
DROP POLICY IF EXISTS "Enable update for all users" ON public.customer_profiles;

-- Create OPEN Policy for Anon Key (since we manage auth manually via phone)
CREATE POLICY "Enable all access for customers" ON public.customer_profiles
FOR ALL
USING (true)
WITH CHECK (true);

-- 2. FIX USER ADDRESSES RLS
-- Allows saving addresses
ALTER TABLE public.user_addresses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Enable all access for addresses" ON public.user_addresses;

CREATE POLICY "Enable all access for addresses" ON public.user_addresses
FOR ALL
USING (true)
WITH CHECK (true);


-- 3. ENSURE TABLE COLUMNS EXIST
-- Add missing columns that might cause sync failure
ALTER TABLE public.customer_profiles 
ADD COLUMN IF NOT EXISTS full_name text,
ADD COLUMN IF NOT EXISTS email text,
ADD COLUMN IF NOT EXISTS avatar_url text,
ADD COLUMN IF NOT EXISTS fcm_token text,
ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();


-- 4. FIX USER CONTEXT FUNCTION (For RLS filtering if used)
DROP FUNCTION IF EXISTS set_current_user(uuid, text);

CREATE OR REPLACE FUNCTION set_current_user(user_id uuid, phone_number text)
RETURNS void AS $$
BEGIN
  PERFORM set_config('app.current_user_id', user_id::text, false);
  PERFORM set_config('app.current_user_phone', phone_number, false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 5. RELOAD SCHEMA CACHE
NOTIFY pgrst, 'reload schema';
