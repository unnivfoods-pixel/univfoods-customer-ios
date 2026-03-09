-- 🛰️ THE DEFINITIVE REALTIME UNIFIER (V10)
-- This script eliminates all synchronization gaps across the UNIV grid.

BEGIN;

-- 1. SCHEMA RECOVERY & IDENTITY ANCHORING
-- Ensure vendors can be uniquely identified by their owner (Required for Realtime Filters)
ALTER TABLE public.vendors DROP CONSTRAINT IF EXISTS unique_vendor_owner;
ALTER TABLE public.vendors ADD CONSTRAINT unique_vendor_owner UNIQUE (owner_id);

-- 2. FULL REPLICATION LOGGING
-- Without FULL identity, realtime filters on specific columns often fail or return null payloads.
ALTER TABLE public.vendors REPLICA IDENTITY FULL;
ALTER TABLE public.products REPLICA IDENTITY FULL;
ALTER TABLE public.orders REPLICA IDENTITY FULL;
ALTER TABLE public.delivery_riders REPLICA IDENTITY FULL;
ALTER TABLE public.notifications REPLICA IDENTITY FULL;

-- 3. GLOBAL BROADCAST ACTIVATION
-- Rebuilding the publication ensures all table alterations are captured.
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

-- 4. BOUTIQUE SECURITY NODES (RLS)
-- Ensuring vendors have administrative rights over their specific operational data.
ALTER TABLE public.vendors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Vendors: Select own profile" ON public.vendors;
CREATE POLICY "Vendors: Select own profile" ON public.vendors FOR SELECT USING (owner_id::text = auth.uid()::text OR auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Vendors: Update own profile" ON public.vendors;
CREATE POLICY "Vendors: Update own profile" ON public.vendors FOR UPDATE USING (owner_id::text = auth.uid()::text);

DROP POLICY IF EXISTS "Vendors: Manage own menu" ON public.products;
CREATE POLICY "Vendors: Manage own menu" ON public.products 
FOR ALL USING (
    vendor_id IN (SELECT id FROM public.vendors WHERE owner_id::text = auth.uid()::text)
) WITH CHECK (
    vendor_id IN (SELECT id FROM public.vendors WHERE owner_id::text = auth.uid()::text)
);

-- 5. DATA NORMALIZATION (Capitalize for App Matching)
UPDATE public.vendors SET status = 'ONLINE' WHERE status = 'Active' OR status = 'active';

COMMIT;

NOTIFY pgrst, 'reload schema';
