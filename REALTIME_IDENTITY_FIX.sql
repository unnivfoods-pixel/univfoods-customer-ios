-- ⚡ SIMPLIFIED REAL-TIME FIX (FOR ALL TABLES)
-- This script skips adding tables to publication since it's already set to FOR ALL TABLES.
-- It focuses on data integrity (Identity Full) and RLS.

BEGIN;

-- 1. Ensure all data is sent in the real-time payload for key tables
-- This is critical even if "FOR ALL TABLES" is on.
ALTER TABLE public.products REPLICA IDENTITY FULL;
ALTER TABLE public.categories REPLICA IDENTITY FULL;
ALTER TABLE public.vendors REPLICA IDENTITY FULL;
ALTER TABLE public.orders REPLICA IDENTITY FULL;

-- 2. Ensure RLS doesn't block "SELECT" for the public/real-time subscribers
-- Allow anyone to see products (Menu display)
DROP POLICY IF EXISTS "Enable read for all products" ON public.products;
CREATE POLICY "Enable read for all products" ON public.products FOR SELECT USING (true);

DROP POLICY IF EXISTS "Enable read for all categories" ON public.categories;
CREATE POLICY "Enable read for all categories" ON public.categories FOR SELECT USING (true);

DROP POLICY IF EXISTS "Enable read for all vendors" ON public.vendors;
CREATE POLICY "Enable read for all vendors" ON public.vendors FOR SELECT USING (true);

COMMIT;

NOTIFY pgrst, 'reload schema';
