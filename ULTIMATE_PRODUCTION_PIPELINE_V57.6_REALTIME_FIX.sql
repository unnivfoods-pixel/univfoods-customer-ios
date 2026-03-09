
-- ULTIMATE REALTIME SYNC ACTIVATOR & PERMISSIONS V57.6
-- 🎯 MISSION: Force Real-time and fix permission blockers for Vendor App.
-- 🛠️ WHY: Tables were not in the Realtime Publication or lacked read permissions.
-- 🧪 SYNC: Broad-spectrum Realtime enabled for VENDOR/CUSTOMER/DELIVERY.

BEGIN;

-- 1. RECREATE CORE PUBLICATION (The Broadcast Hub)
-- This is critical. Without this, no changes reach the app.
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

-- 2. HARDEN REPLICA IDENTITIES
-- Ensures the FULL record is sent on every update.
ALTER TABLE public.orders REPLICA IDENTITY FULL;
ALTER TABLE public.vendors REPLICA IDENTITY FULL;
ALTER TABLE public.products REPLICA IDENTITY FULL;
ALTER TABLE public.wallets REPLICA IDENTITY FULL;
ALTER TABLE public.delivery_riders REPLICA IDENTITY FULL;

-- 3. UNLOCK PERMISSIONS (Testing Mode)
-- Grants everyone read access to ensure the app doesn't hit a wall.
GRANT USAGE ON SCHEMA public TO authenticated, anon;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO authenticated, anon;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated, anon;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated, anon;

-- 4. THE "TRUTH" LOGISTICS VIEW (Hardened)
CREATE OR REPLACE VIEW public.order_details_v3 AS
SELECT 
    o.*,
    v.name as vendor_name, 
    v.owner_id as vendor_owner_id,
    cp.full_name as customer_name,
    dr.name as rider_name
FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id = v.id
LEFT JOIN public.customer_profiles cp ON o.customer_id = cp.id
LEFT JOIN public.delivery_riders dr ON o.rider_id = dr.id;

-- 5. ENSURE BOOTSTRAP FUNCTION ACCESSIBILITY
ALTER FUNCTION public.get_unified_bootstrap_data(TEXT, TEXT) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.get_unified_bootstrap_data(TEXT, TEXT) TO authenticated, anon;

-- 6. VENDOR IDENTITY LINKING FOR TESTING
-- If you are the first user, claim the flagship shop.
UPDATE public.vendors 
SET owner_id = (SELECT id FROM auth.users LIMIT 1)
WHERE (owner_id IS NULL OR owner_id = '') 
AND (name ILIKE '%Royal%' OR id IS NOT NULL)
AND EXISTS (SELECT 1 FROM auth.users)
ORDER BY id ASC
LIMIT 1;

COMMIT;
NOTIFY pgrst, 'reload schema';
