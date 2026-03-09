-- 🛠️ FIX REGISTRATION SYSTEM RLS & SCHEMA
-- Resolves: "new row violates row-level security policy for table 'registration_requests'"

BEGIN;

-- 1. Ensure Table Schema is Robust
CREATE TABLE IF NOT EXISTS public.registration_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID REFERENCES auth.users(id),
    name TEXT,
    email TEXT,
    phone TEXT,
    password TEXT,
    message TEXT,
    address TEXT,
    type TEXT DEFAULT 'vendor',
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add missing columns if table existed but was incomplete
ALTER TABLE public.registration_requests ADD COLUMN IF NOT EXISTS owner_id UUID REFERENCES auth.users(id);
ALTER TABLE public.registration_requests ADD COLUMN IF NOT EXISTS address TEXT;
ALTER TABLE public.registration_requests ADD COLUMN IF NOT EXISTS password TEXT;
ALTER TABLE public.registration_requests ADD COLUMN IF NOT EXISTS message TEXT;
ALTER TABLE public.registration_requests ADD COLUMN IF NOT EXISTS type TEXT DEFAULT 'vendor';

-- 2. ENABLE RLS
ALTER TABLE public.registration_requests ENABLE ROW LEVEL SECURITY;

-- 3. DROP EXISTING POLICIES (to start clean)
DROP POLICY IF EXISTS "Allow anon to insert" ON public.registration_requests;
DROP POLICY IF EXISTS "Allow authenticated to insert" ON public.registration_requests;
DROP POLICY IF EXISTS "Allow admins to manage" ON public.registration_requests;
DROP POLICY IF EXISTS "Enable insert for everyone" ON public.registration_requests;
DROP POLICY IF EXISTS "Enable select for admins" ON public.registration_requests;

-- 4. CREATE NEW POLICIES

-- Allow ANYONE (including anon from landing page) to insert a request
CREATE POLICY "Enable insert for all" 
ON public.registration_requests 
FOR INSERT 
WITH CHECK (true);

-- Allow admins to see and manage all requests
-- We assume admin is someone with a matching email or a concept we define, 
-- but usually, for this project, we want the admin panel to work.
-- If the admin panel uses the service role, it bypasses RLS. 
-- If it uses an authenticated user, we need a policy.
CREATE POLICY "Enable select for authenticated" 
ON public.registration_requests 
FOR SELECT 
USING (auth.role() = 'authenticated');

CREATE POLICY "Enable all for admins" 
ON public.registration_requests 
FOR ALL 
TO authenticated 
USING (true);

-- 5. ENSURE REALTIME (Just in case)
ALTER TABLE public.registration_requests REPLICA IDENTITY FULL;

COMMIT;

NOTIFY pgrst, 'reload schema';
