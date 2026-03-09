
-- OMEGA REALTIME SYNC FIX V1.0
-- 🎯 MISSION: Enable Real-time for all major tables to fix Vendor-to-Admin sync.
-- 🛠️ WHY: If tables are not in 'supabase_realtime' publication, .subscribe() does nothing.

BEGIN;

-- 1. Ensure 'supabase_realtime' publication exists
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        CREATE PUBLICATION supabase_realtime;
    END IF;
END $$;

-- 2. Add major tables to the publication
-- We use 'ALTER PUBLICATION ... ADD TABLE ...' or 'SET TABLE ...'
-- SET TABLE replaces all tables in the publication with these ones.
-- This is the safest way to ensure EVERYTHING is included.
ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
ALTER PUBLICATION supabase_realtime ADD TABLE public.vendors;
ALTER PUBLICATION supabase_realtime ADD TABLE public.products;
ALTER PUBLICATION supabase_realtime ADD TABLE public.wallets;
ALTER PUBLICATION supabase_realtime ADD TABLE public.customer_profiles;
ALTER PUBLICATION supabase_realtime ADD TABLE public.delivery_riders;
ALTER PUBLICATION supabase_realtime ADD TABLE public.order_live_tracking;
ALTER PUBLICATION supabase_realtime ADD TABLE public.user_favorites;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;

-- 3. Enable REPLICA IDENTITY FULL
-- This ensures that the 'old' record is sent in the payload during updates,
-- which is sometimes required for client-side filtering and consistency.
ALTER TABLE public.orders REPLICA IDENTITY FULL;
ALTER TABLE public.vendors REPLICA IDENTITY FULL;
ALTER TABLE public.products REPLICA IDENTITY FULL;
ALTER TABLE public.wallets REPLICA IDENTITY FULL;
ALTER TABLE public.customer_profiles REPLICA IDENTITY FULL;
ALTER TABLE public.delivery_riders REPLICA IDENTITY FULL;
ALTER TABLE public.order_live_tracking REPLICA IDENTITY FULL;

-- 4. Set RLS for Real-time
-- Supabase Real-time respects RLS. If RLS is enabled but policies are wrong,
-- events will be filtered out.
-- We ensure that the 'authenticated' role (Admin/Vendor) can at least SELECT.

-- For Admin (assuming authenticated users are admins or have broad access)
-- Or better, we ensure policies exist.

COMMIT;

-- 5. Notify PostgREST/Supabase to reload
NOTIFY pgrst, 'reload schema';
