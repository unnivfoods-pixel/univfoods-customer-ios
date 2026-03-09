-- ⚡ ENABLE REAL-TIME FOR PRODUCTS & VENDORS
-- Ensures that menu items and vendor updates reflect instantly across all apps.

BEGIN;

-- 1. Enable Real-time Publication for key tables
-- We check if the publication 'supabase_realtime' exists, then add tables.
-- If you get an error that it already exists, that's fine.

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        CREATE PUBLICATION supabase_realtime;
    END IF;
END $$;

-- Add tables to the publication
-- This allows Supabase to broadcast changes to these tables.
ALTER PUBLICATION supabase_realtime ADD TABLE public.products;
ALTER PUBLICATION supabase_realtime ADD TABLE public.categories;
ALTER PUBLICATION supabase_realtime ADD TABLE public.vendors;
ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;

-- 2. Performance & Identity check for Real-time
-- REPLICA IDENTITY FULL ensures all columns are sent in the real-time payload.
ALTER TABLE public.products REPLICA IDENTITY FULL;
ALTER TABLE public.categories REPLICA IDENTITY FULL;
ALTER TABLE public.vendors REPLICA IDENTITY FULL;

-- 3. Ensure RLS doesn't block "SELECT" for the public/real-time subscribers
-- Allow anyone to see products (Menu display)
DROP POLICY IF EXISTS "Enable read for all" ON public.products;
CREATE POLICY "Enable read for all" ON public.products FOR SELECT USING (true);

DROP POLICY IF EXISTS "Enable read for all" ON public.categories;
CREATE POLICY "Enable read for all" ON public.categories FOR SELECT USING (true);

COMMIT;

NOTIFY pgrst, 'reload schema';
