-- 🛰️ SUPER REALTIME CONNECTION MASTER (V9)
-- This script fixes EVERY roadblock preventing Vendor App from syncing.

BEGIN;

-- 1. IDENTITIY SYNC (Crucial for UPSERT & Filters)
ALTER TABLE public.vendors ADD CONSTRAINT unique_vendor_owner UNIQUE (owner_id);
ALTER TABLE public.vendors REPLICA IDENTITY FULL;
ALTER TABLE public.products REPLICA IDENTITY FULL;
ALTER TABLE public.orders REPLICA IDENTITY FULL;
ALTER TABLE public.delivery_riders REPLICA IDENTITY FULL;
ALTER TABLE public.notifications REPLICA IDENTITY FULL;

-- 2. STATUS NORMALIZATION
-- Ensure all statuses match the apps' expectations
UPDATE public.vendors SET status = 'ONLINE' WHERE status = 'Active';

-- 3. RLS REINFORCEMENT (Allow vendors to manage their own assets)
DROP POLICY IF EXISTS "Vendors manage own assets" ON public.products;
CREATE POLICY "Vendors manage own assets" ON public.products
FOR ALL USING (
    vendor_id IN (SELECT id FROM public.vendors WHERE owner_id = auth.uid())
) WITH CHECK (
    vendor_id IN (SELECT id FROM public.vendors WHERE owner_id = auth.uid())
);

DROP POLICY IF EXISTS "Vendors manage own profile" ON public.vendors;
CREATE POLICY "Vendors manage own profile" ON public.vendors
FOR ALL USING (owner_id = auth.uid()) WITH CHECK (owner_id = auth.uid());

-- 4. GLOBAL REALTIME ACTIVATION
-- Re-create the publication to ensure ALL tables are truly broadcasting
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

-- 5. NOTIFICATION HUB FIX
-- Ensure read_status vs is_read naming is consistent
DO $$ 
BEGIN
    ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS is_read BOOLEAN DEFAULT false;
    ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS event_type TEXT DEFAULT 'INFO';
END $$;

COMMIT;

NOTIFY pgrst, 'reload schema';
