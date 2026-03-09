-- REGISTRATION SYSTEM REPAIR (v15.0)
-- 🎯 MISSION: Fix "Database error saving new user" during Landing Page Signup.

BEGIN;

-- 1. REPAIR REGISTRATION_REQUESTS TABLE SCHEMA
-- This ensures the table can handle the data sent from the landing website.
DO $$
BEGIN
    -- Create table if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'registration_requests') THEN
        CREATE TABLE public.registration_requests (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            name TEXT,
            email TEXT,
            phone TEXT,
            password TEXT,
            message TEXT,
            address TEXT,
            type TEXT DEFAULT 'vendor',
            status TEXT DEFAULT 'pending',
            owner_id TEXT, -- Store as TEXT to handle both UUID and UUID strings
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );
    ELSE
        -- Add missing columns safely
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'registration_requests' AND column_name = 'address') THEN
            ALTER TABLE public.registration_requests ADD COLUMN address TEXT;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'registration_requests' AND column_name = 'owner_id') THEN
            ALTER TABLE public.registration_requests ADD COLUMN owner_id TEXT;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'registration_requests' AND column_name = 'password') THEN
            ALTER TABLE public.registration_requests ADD COLUMN password TEXT;
        END IF;
    END IF;
END $$;

-- 2. FIX RLS (Row Level Security)
-- This allows the Anonymous Website visitors (Landing Page) to SUBMIT their application.
ALTER TABLE public.registration_requests ENABLE ROW LEVEL SECURITY;

-- Drop old policies to prevent duplicates
DROP POLICY IF EXISTS "Public can submit registration" ON public.registration_requests;
DROP POLICY IF EXISTS "Admin can manage registrations" ON public.registration_requests;
DROP POLICY IF EXISTS "Allow anonymous inserts" ON public.registration_requests;

-- Create mission critical policies
CREATE POLICY "Allow anonymous inserts" 
ON public.registration_requests 
FOR INSERT 
TO anon 
WITH CHECK (true);

CREATE POLICY "Admin can manage registrations" 
ON public.registration_requests 
FOR ALL 
TO service_role 
USING (true);

-- 3. PERMISSIONS
GRANT ALL ON public.registration_requests TO anon, authenticated, service_role;

-- 4. CLEANUP: Ensure existing "long ID" orders are also synced
INSERT INTO public.users (id, email, full_name)
SELECT id, email, 'Real User' FROM auth.users
WHERE id::TEXT NOT IN (SELECT id::TEXT FROM public.users)
ON CONFLICT (id) DO NOTHING;

COMMIT;

SELECT 'REGISTRATION SYSTEM ONLINE (v15.0) - REPAIRED' as report;
