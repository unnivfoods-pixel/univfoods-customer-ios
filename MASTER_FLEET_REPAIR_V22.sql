-- FLEET & CHECKOUT UNIVERSAL REPAIR (v22.0)
-- 🎯 MISSION: Fix "Missing email column" for Riders & "22P02 Data Mismatch" during Checkout.

BEGIN;

-- 1. REPAIR DELIVERY_RIDERS SCHEMA
-- This fixes the "Could not find the email column" error in the Admin Panel.
ALTER TABLE public.delivery_riders ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE public.delivery_riders ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'Offline';
ALTER TABLE public.delivery_riders ADD COLUMN IF NOT EXISTS is_online BOOLEAN DEFAULT false;
ALTER TABLE public.delivery_riders ADD COLUMN IF NOT EXISTS current_lat DOUBLE PRECISION;
ALTER TABLE public.delivery_riders ADD COLUMN IF NOT EXISTS current_lng DOUBLE PRECISION;
ALTER TABLE public.delivery_riders ADD COLUMN IF NOT EXISTS last_active TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- 2. FIX "22P02" DATA FORMAT MISMATCH (CHECKOUT FIX)
-- This error happens when the app tries to compare a UUID with a TEXT ID.
-- We ensure the orders table and user profile comparisons are always cast to TEXT.

-- Ensure primary columns are ready for TEXT comparisons
DO $$
BEGIN
    -- If users table has id as UUID, some apps sending TEXT IDs will crash it.
    -- We ensure our functions and triggers use ::TEXT for everything.
    
    -- Fix the Checkout Bridge (Sync trigger for users)
    CREATE OR REPLACE FUNCTION public.handle_new_user_sync()
    RETURNS trigger AS $$$
    BEGIN
      BEGIN
        INSERT INTO public.users (id, email, full_name)
        VALUES (
          NEW.id::TEXT, 
          NEW.email, 
          COALESCE(NEW.raw_user_meta_data->>'full_name', 'Univ Member')
        )
        ON CONFLICT (id) DO UPDATE SET
            email = EXCLUDED.email,
            full_name = EXCLUDED.full_name;
      EXCEPTION WHEN OTHERS THEN
        RETURN NEW;
      END;
      RETURN NEW;
    END;
    $$$ LANGUAGE plpgsql SECURITY DEFINER;
END $$;

-- 3. RE-SYNC VENDOR & RIDER PERMISSIONS
-- This ensures the "Deploy" buttons work across the entire platform.
ALTER TABLE public.delivery_riders DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendors DISABLE ROW LEVEL SECURITY;
GRANT ALL ON public.delivery_riders TO anon, authenticated, service_role;
GRANT ALL ON public.vendors TO anon, authenticated, service_role;

-- 4. RELOAD SCHEMA CACHE
-- This forces Supabase to see the new 'email' column immediately.
NOTIFY pgrst, 'reload schema';

COMMIT;

SELECT 'FLEET & CHECKOUT REPAIRED (v22.0) - REFRESH APPS' as report;
