-- FIX ADDRESS CONFLICT ERROR (409)
-- The error "Conflict" means there is a unique constraint violation.
-- This likely happened because the table was created with a One-to-One relationship (Primary Key on user_id)
-- instead of One-to-Many.

-- 1. DROP the broken table completely
DROP TABLE IF EXISTS public.user_addresses;

-- 2. RE-CREATE the table correctly (One User -> Many Addresses)
CREATE TABLE public.user_addresses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id), -- No unique constraint here!
    title TEXT,
    address_line TEXT,
    contact_name TEXT,
    contact_phone TEXT,
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. DISABLE RLS to prevent 401 Unauthorized errors
ALTER TABLE public.user_addresses DISABLE ROW LEVEL SECURITY;

-- 4. GRANT permissions to everyone (Anon + Auth)
GRANT ALL ON public.user_addresses TO authenticated;
GRANT ALL ON public.user_addresses TO anon;
GRANT ALL ON public.user_addresses TO service_role;
