-- =========================================================
-- FINAL FIX FOR USER ADDRESSES (DEMO MODE COMPATIBILITY)
-- =========================================================

-- 1. Ensure table exists with relaxed constraints
CREATE TABLE IF NOT EXISTS public.user_addresses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL, -- Keep NOT NULL but we will remove the FK constraint
    title TEXT NOT NULL,
    address_line TEXT NOT NULL,
    contact_name TEXT,
    contact_phone TEXT,
    latitude DOUBLE PRECISION DEFAULT 0,
    longitude DOUBLE PRECISION DEFAULT 0,
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Remove Foreign Key constraint if it exists (to allow Forced User IDs)
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 
        FROM information_schema.table_constraints 
        WHERE constraint_name = 'user_addresses_user_id_fkey' 
        AND table_name = 'user_addresses'
    ) THEN
        ALTER TABLE public.user_addresses DROP CONSTRAINT user_addresses_user_id_fkey;
    END IF;
END $$;

-- 3. Add Unique Constraint required for the 'upsert' logic in the App
-- Drop first to be safe
ALTER TABLE public.user_addresses DROP CONSTRAINT IF EXISTS unique_user_address_title;
ALTER TABLE public.user_addresses ADD CONSTRAINT unique_user_address_title UNIQUE (user_id, title);

-- 4. Disable RLS for Demo consistency
ALTER TABLE public.user_addresses DISABLE ROW LEVEL SECURITY;

-- 5. Grant permissions
GRANT ALL ON public.user_addresses TO anon;
GRANT ALL ON public.user_addresses TO authenticated;
GRANT ALL ON public.user_addresses TO service_role;

-- 6. Refresh cache
NOTIFY pgrst, 'reload schema';
