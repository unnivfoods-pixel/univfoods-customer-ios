-- ==========================================
-- 🛡️ NON-DESTRUCTIVE DATABASE FIX (V2)
-- ONLY adds columns and fixes RLS. NO DATA LOSS.
-- ==========================================

-- 1. ADD MISSING COLUMNS (SAFE)
DO $$
BEGIN
    -- Add cost_for_two
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='vendors' AND column_name='cost_for_two') THEN
        ALTER TABLE public.vendors ADD COLUMN cost_for_two integer DEFAULT 200;
    END IF;

    -- Add delivery_time
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='vendors' AND column_name='delivery_time') THEN
        ALTER TABLE public.vendors ADD COLUMN delivery_time integer DEFAULT 30;
    END IF;

    -- Add cuisine_type
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='vendors' AND column_name='cuisine_type') THEN
        ALTER TABLE public.vendors ADD COLUMN cuisine_type text;
    END IF;

    -- Add image_url
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='vendors' AND column_name='image_url') THEN
        ALTER TABLE public.vendors ADD COLUMN image_url text;
    END IF;

    -- Add zone_id
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='vendors' AND column_name='zone_id') THEN
        ALTER TABLE public.vendors ADD COLUMN zone_id uuid;
    END IF;

    -- Add is_promoted
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='vendors' AND column_name='is_promoted') THEN
        ALTER TABLE public.vendors ADD COLUMN is_promoted boolean DEFAULT false;
    END IF;

    -- Add status
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='vendors' AND column_name='status') THEN
        ALTER TABLE public.vendors ADD COLUMN status text DEFAULT 'active';
    END IF;
END $$;

-- 2. ENSURE RLS IS CONFIGURED FOR PUBLIC ACCESS
-- We don't truncate, we just ensure people can read.
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.delivery_zones ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow Public Read Categories" ON public.categories;
CREATE POLICY "Allow Public Read Categories" ON public.categories FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow Public Read Vendors" ON public.vendors;
CREATE POLICY "Allow Public Read Vendors" ON public.vendors FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow Public Read Products" ON public.products;
CREATE POLICY "Allow Public Read Products" ON public.products FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow Public Read Zones" ON public.delivery_zones;
CREATE POLICY "Allow Public Read Zones" ON public.delivery_zones FOR SELECT USING (true);

-- 3. ENABLE REALTIME (Smarter Check)
-- Note: If your publication is set to "FOR ALL TABLES", these commands aren't needed.
-- We use a DO block to avoid errors if they are already added or if the pub is FOR ALL TABLES.
DO $$
BEGIN
    -- Only try to add if NOT "FOR ALL TABLES"
    IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime' AND puballtables = true) THEN
        BEGIN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.categories;
        EXCEPTION WHEN others THEN RAISE NOTICE 'Skipping categories - likely already added';
        END;
        
        BEGIN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.vendors;
        EXCEPTION WHEN others THEN RAISE NOTICE 'Skipping vendors - likely already added';
        END;

        BEGIN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.products;
        EXCEPTION WHEN others THEN RAISE NOTICE 'Skipping products - likely already added';
        END;

        BEGIN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
        EXCEPTION WHEN others THEN RAISE NOTICE 'Skipping orders - likely already added';
        END;

        BEGIN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
        EXCEPTION WHEN others THEN RAISE NOTICE 'Skipping notifications - likely already added';
        END;
    END IF;
END $$;
