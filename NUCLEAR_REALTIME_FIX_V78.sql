-- 🚨 NUCLEAR REALTIME & REPLICA RECOVERY (V78)
-- MISSION: Ensure every order update is broadcasted and captured.

BEGIN;

-- 1. FORCE REPLICA IDENTITY FULL (Critical for partial updates)
ALTER TABLE public.orders REPLICA IDENTITY FULL;
ALTER TABLE public.vendors REPLICA IDENTITY FULL;
ALTER TABLE public.delivery_riders REPLICA IDENTITY FULL;
ALTER TABLE public.customer_profiles REPLICA IDENTITY FULL;
ALTER TABLE public.order_items REPLICA IDENTITY FULL;
ALTER TABLE public.order_live_tracking REPLICA IDENTITY FULL;

-- 2. RESET REALTIME PUBLICATION
-- Sometimes 'FOR ALL TABLES' is buggy after schema changes. 
-- We explicitly define the core logistics tables.
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

-- 3. ENSURE RLS IS NOT BLOCKING REALTIME FOR CUSTOMERS
-- Every customer must be able to see their own orders for the websocket to push data to them.
DO $$ 
BEGIN
    -- This is a safety check. Usually RLS is already set.
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'orders' AND policyname = 'Customers can view own orders'
    ) THEN
        ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
        CREATE POLICY "Customers can view own orders" ON public.orders
        FOR SELECT TO authenticated
        USING (customer_id::text = auth.uid()::text);
    END IF;
END $$;

COMMIT;
