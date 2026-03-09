-- 🛠️ FIX CUSTOMER PROFILES & RLS
-- Ensures the customer_profiles table is accessible and compatible with Firebase Auth Custom Scheme

-- 1. Ensure Table Exists
CREATE TABLE IF NOT EXISTS public.customer_profiles (
    id TEXT PRIMARY KEY, -- Firebase UID (Text, not UUID)
    phone TEXT,
    email TEXT,
    full_name TEXT,
    avatar_url TEXT,
    fcm_token TEXT,
    account_status TEXT DEFAULT 'Active',
    is_blocked BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 2. Open RLS for Customer App (Since we use Firebase Auth ID as simple text)
-- In a stricter production environment, we would use a signed JWT from Firebase, but for this hybrid approach:
ALTER TABLE public.customer_profiles ENABLE ROW LEVEL SECURITY;

-- Allow SELECT to everyone (Frontend filters by ID)
DROP POLICY IF EXISTS "Allow public read" ON public.customer_profiles;
CREATE POLICY "Allow public read" ON public.customer_profiles
    FOR SELECT USING (true);

-- Allow INSERT to everyone (Sign Up)
DROP POLICY IF EXISTS "Allow public insert" ON public.customer_profiles;
CREATE POLICY "Allow public insert" ON public.customer_profiles
    FOR INSERT WITH CHECK (true);

-- Allow UPDATE to everyone (Profile Edit)
DROP POLICY IF EXISTS "Allow public update" ON public.customer_profiles;
CREATE POLICY "Allow public update" ON public.customer_profiles
    FOR UPDATE USING (true);

-- 3. Sync permissions for Realtime
-- NOTE: If your publication is "FOR ALL TABLES", the following line will error. That is fine.
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.customer_profiles;

-- 4. FIX USER ADDRESSES TABLE (Must support Text User IDs from Firebase)
-- Recreate table to allow TEXT user_id and remove UUID/FK constraints
DROP TABLE IF EXISTS public.user_addresses;
CREATE TABLE public.user_addresses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL, -- Changed from UUID to TEXT to support Firebase UID
    label TEXT, -- Home, Work, etc.
    address_line TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Open RLS for Addresses
ALTER TABLE public.user_addresses ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow public read addresses" ON public.user_addresses;
CREATE POLICY "Allow public read addresses" ON public.user_addresses FOR SELECT USING (true);
DROP POLICY IF EXISTS "Allow public insert addresses" ON public.user_addresses;
CREATE POLICY "Allow public insert addresses" ON public.user_addresses FOR INSERT WITH CHECK (true);
DROP POLICY IF EXISTS "Allow public update addresses" ON public.user_addresses;
CREATE POLICY "Allow public update addresses" ON public.user_addresses FOR UPDATE USING (true);
DROP POLICY IF EXISTS "Allow public delete addresses" ON public.user_addresses;
CREATE POLICY "Allow public delete addresses" ON public.user_addresses FOR DELETE USING (true);

-- Add to Realtime
-- NOTE: If your publication is "FOR ALL TABLES", the following line will error. That is fine.
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.user_addresses;
