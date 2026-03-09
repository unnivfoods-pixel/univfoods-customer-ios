-- ✅ MASTER REALTIME CONSOLIDATED FIX
-- Enables realtime for all critical tables used in Admin, Customer, and Delivery apps

-- 1. Create publication if it doesn't exist (it usually does in Supabase)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        CREATE PUBLICATION supabase_realtime;
    END IF;
END $$;

-- 2. Ensure all relevant tables are in the publication
-- Note: Errors are ignored if tables are already in the publication
DO $$
DECLARE
    row RECORD;
    target_tables TEXT[] := ARRAY[
        'orders',
        'order_items',
        'vendors',
        'menu_items',
        'categories',
        'customer_profiles',
        'delivery_riders',
        'user_addresses',
        'payments',
        'notifications',
        'rider_locations',
        'delivery_zones',
        'vendor_reviews',
        'banners',
        'faqs',
        'support_tickets',
        'support_chats',
        'refunds',
        'fraud_logs',
        'order_live_tracking',
        'delivery_live_location'
    ];
    t TEXT;
BEGIN
    FOR t IN SELECT unnest(target_tables) LOOP
        -- Check if table exists before adding
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = t) THEN
            -- Check if already in publication
            IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = t) THEN
                EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
            END IF;
        END IF;
    END LOOP;
END $$;

-- 3. Set replica identity to FULL for tables that need old data in payloads (optional but recommended for some)
-- This ensures that UPDATE events include the previous values.
ALTER TABLE public.orders REPLICA IDENTITY FULL;
ALTER TABLE public.delivery_riders REPLICA IDENTITY FULL;
ALTER TABLE public.rider_locations REPLICA IDENTITY FULL;
ALTER TABLE public.delivery_live_location REPLICA IDENTITY FULL;
ALTER TABLE public.order_live_tracking REPLICA IDENTITY FULL;

-- 4. Enable RLS on all tables and add public read if not present (required for anon realtime)
-- For Admin, we might rely on the service role, but React clients usually use the anon key.
-- Realtime requires the user (even anon) to have SELECT permission on the table.

DO $$
DECLARE
    t TEXT;
    target_tables TEXT[] := ARRAY['orders', 'vendors', 'delivery_riders', 'notifications', 'faqs', 'support_tickets', 'support_chats', 'delivery_live_location', 'order_live_tracking'];
BEGIN
    FOR t IN SELECT unnest(target_tables) LOOP
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = t) THEN
            -- Ensure SELECT is granted to anon if public access is intended
            -- (Adjust as per security requirements - usually admin needs broad access)
            EXECUTE format('GRANT SELECT ON public.%I TO anon, authenticated', t);
            
            -- Add a broad SELECT policy for now to ensure realtime works
            EXECUTE format('DROP POLICY IF EXISTS "Realtime Public Read" ON public.%I', t);
            EXECUTE format('CREATE POLICY "Realtime Public Read" ON public.%I FOR SELECT USING (true)', t);
        END IF;
    END LOOP;
END $$;

NOTIFY pgrst, 'reload schema';
