-- 🛡️ STABILIZE_VENDORS_V1.sql
-- Fixes Vendor table schema to match Admin Panel expectations

DO $$ 
BEGIN
    -- 1. Identity & Core (Already TEXT in V60, but let's be sure)
    ALTER TABLE IF EXISTS public.vendors ALTER COLUMN id TYPE TEXT USING id::TEXT;
    ALTER TABLE IF EXISTS public.vendors ALTER COLUMN owner_id TYPE TEXT USING owner_id::TEXT;

    -- 2. Column Alignment (Matching Vendors.jsx payload)
    
    -- Rename 'cuisine' to 'cuisine_type' if it exists and 'cuisine_type' doesn't
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='vendors' AND column_name='cuisine') 
       AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='vendors' AND column_name='cuisine_type') THEN
        ALTER TABLE public.vendors RENAME COLUMN cuisine TO cuisine_type;
    END IF;

    -- Rename 'image_url' to 'banner_url' if it exists and 'banner_url' doesn't
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='vendors' AND column_name='image_url') 
       AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='vendors' AND column_name='banner_url') THEN
        ALTER TABLE public.vendors RENAME COLUMN image_url TO banner_url;
    END IF;

    -- Add missing columns
    ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS cuisine_type text DEFAULT 'North Indian';
    ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS banner_url text;
    ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS manager text;
    ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS open_time text DEFAULT '09:00';
    ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS close_time text DEFAULT '22:00';
    ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS is_pure_veg boolean DEFAULT false;
    ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS has_offers boolean DEFAULT false;
    ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS delivery_radius_km numeric DEFAULT 15;
    ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS rating numeric DEFAULT 5.0;
    ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS status text DEFAULT 'ONLINE';
    ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS email text;
    ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS review_count integer DEFAULT 0;
    ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS pending_payout numeric DEFAULT 0;

END $$;

-- 3. Security Check
ALTER TABLE public.vendors ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public read" ON public.vendors;
CREATE POLICY "Public read" ON public.vendors FOR SELECT USING (true);

DROP POLICY IF EXISTS "All access for authenticated" ON public.vendors;
CREATE POLICY "All access for authenticated" ON public.vendors FOR ALL USING (true); -- Allow Admin Panel to manage

-- 4. Realtime Check
ALTER TABLE public.vendors REPLICA IDENTITY FULL;
DROP PUBLICATION IF EXISTS supabase_realtime_vendors;
CREATE PUBLICATION supabase_realtime_vendors FOR TABLE public.vendors;
