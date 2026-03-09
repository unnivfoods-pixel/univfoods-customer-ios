/*
ADRENALINE REALTIME SYNC (V13)
------------------------------
1. Force enables Replica Identity FULL for all critical tables.
2. Ensures all tables are in the realtime publication.
3. Fixes RLS to ensure Admin (and the system) can toggle status without friction.
*/

-- 1. Enable Full Replication Identity (Ensures all columns are sent in the update payload)
ALTER TABLE public.vendors REPLICA IDENTITY FULL;
ALTER TABLE public.products REPLICA IDENTITY FULL;
ALTER TABLE public.orders REPLICA IDENTITY FULL;

-- 2. Realtime Publication (Re-check)
-- Ensure the publication exists and contains our tables
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        CREATE PUBLICATION supabase_realtime;
    END IF;
END $$;

-- Add tables if missing (using a safer approach)
ALTER PUBLICATION supabase_realtime DROP TABLE IF EXISTS public.vendors, public.products, public.orders;
ALTER PUBLICATION supabase_realtime ADD TABLE public.vendors, public.products, public.orders;

-- 3. Relax RLS for faster Dev/Admin operations
-- This ensures that when the Admin Panel (React) updates a vendor, the change is accepted immediately.
BEGIN;
  DROP POLICY IF EXISTS "Admin Full Control" ON public.vendors;
  CREATE POLICY "Admin Full Control" ON public.vendors FOR ALL USING (true) WITH CHECK (true);

  DROP POLICY IF EXISTS "Admin Full Control" ON public.products;
  CREATE POLICY "Admin Full Control" ON public.products FOR ALL USING (true) WITH CHECK (true);

  DROP POLICY IF EXISTS "Admin Full Control" ON public.orders;
  CREATE POLICY "Admin Full Control" ON public.orders FOR ALL USING (true) WITH CHECK (true);
COMMIT;

NOTIFY pgrst, 'reload schema';
