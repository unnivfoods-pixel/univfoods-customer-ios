/*
SUPERBASE FIX & FRESH START (V11 - REALTIME & PERMISSIONS FIX)
-----------------------------------------
1. Fixes RLS Policies to allow Admin to DELETE and UPDATE without restrictions.
2. Ensures all tables are in the realtime publication.
3. Clean schema and purge operational data.
*/

-- 1. Schema Base
CREATE TABLE IF NOT EXISTS public.delivery_zones (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  active BOOLEAN DEFAULT true,
  coordinates JSONB,
  delivery_fee NUMERIC DEFAULT 25,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.delivery_zones ADD COLUMN IF NOT EXISTS delivery_fee NUMERIC DEFAULT 25;
ALTER TABLE public.delivery_zones ADD COLUMN IF NOT EXISTS active BOOLEAN DEFAULT true;

-- 2. Vendor Schema Fix
ALTER TABLE public.vendors DROP COLUMN IF EXISTS cuisine;
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS cuisine_type TEXT DEFAULT 'Multi Cuisine';
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS image_url TEXT;
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS banner_url TEXT;
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS delivery_time TEXT DEFAULT '30-45 min';
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'open';
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT true;
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS commission_rate NUMERIC DEFAULT 15;
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS payout_cycle TEXT DEFAULT 'Weekly';
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS manager TEXT;
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS review_count INTEGER DEFAULT 0;
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS rating NUMERIC DEFAULT 5.0;

DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='vendors' AND column_name='zone_id') THEN
    ALTER TABLE public.vendors ADD COLUMN zone_id UUID REFERENCES public.delivery_zones(id) ON DELETE SET NULL;
  END IF;
END $$;

-- 3. PERMISSIONS (RLS) - FIXING DELETE/UPDATE ISSUES
ALTER TABLE public.vendors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.delivery_zones ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow All for Admins" ON public.vendors;
DROP POLICY IF EXISTS "Public Read Vendors" ON public.vendors;
CREATE POLICY "Allow All for Admins" ON public.vendors FOR ALL USING (true); -- Simplified for dev admin

DROP POLICY IF EXISTS "Allow All for Admins" ON public.delivery_zones;
CREATE POLICY "Allow All for Admins" ON public.delivery_zones FOR ALL USING (true);

-- 4. REALTIME ENABLEMENT
-- Force addition of tables to realtime publication
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'vendors') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.vendors;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'delivery_zones') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.delivery_zones;
  END IF;
END $$;

-- 5. Storage Setup
INSERT INTO storage.buckets (id, name, public)
VALUES ('images', 'images', true)
ON CONFLICT (id) DO NOTHING;

BEGIN;
  DROP POLICY IF EXISTS "Public Access" ON storage.objects;
  DROP POLICY IF EXISTS "Public All Access" ON storage.objects;
  CREATE POLICY "Public Access" ON storage.objects FOR SELECT USING (bucket_id = 'images');
  CREATE POLICY "Public All Access" ON storage.objects FOR ALL USING (bucket_id = 'images') WITH CHECK (bucket_id = 'images');
COMMIT;

-- 6. PURGE DATA (CLEAN START)
TRUNCATE TABLE public.delivery_zones RESTART IDENTITY CASCADE; 
TRUNCATE TABLE public.vendors RESTART IDENTITY CASCADE;
TRUNCATE TABLE public.orders RESTART IDENTITY CASCADE;
TRUNCATE TABLE public.delivery_riders RESTART IDENTITY CASCADE;

-- 7. Audit Log
DO $$ 
BEGIN
    INSERT INTO public.app_settings (key, value) 
    VALUES ('system_info', jsonb_build_object('last_refresh', now(), 'status', 'FIXED_PERMISSIONS', 'version', 'V11'))
    ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
END $$;

NOTIFY pgrst, 'reload schema';
COMMENT ON TABLE public.vendors IS 'Schema version 11: Enabled DELETE/UPDATE permissions and Realtime';
