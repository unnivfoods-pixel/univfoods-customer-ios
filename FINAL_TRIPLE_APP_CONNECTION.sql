-- 🔗 FINAL TRIPLE-APP CONNECTION: SYNC & LOGISTICS (FIXED CASTING)
-- This script ensures the Admin Panel, Vendor App, and Delivery App are functionally bonded.
-- It resolves RLS blocks, synchronizes status keys, and enables cross-app operational flow.
-- Added explicit ::text casting to resolve UUID vs TEXT comparison errors.

BEGIN;

-- 1. ENHANCE ORDERS TABLE FOR DUAL-APP CONTROL
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS rejection_reason TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS pickup_otp TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_otp TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS prepared_at TIMESTAMP WITH TIME ZONE;

-- 2. UNIVERSAL LOGISTICS RLS (The "Operational Bond")
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

-- CLEAR OLD POLICIES
DROP POLICY IF EXISTS "Vendors manage own orders" ON public.orders;
DROP POLICY IF EXISTS "Riders manage assigned orders" ON public.orders;
DROP POLICY IF EXISTS "Customers view own orders" ON public.orders;
DROP POLICY IF EXISTS "Global order access" ON public.orders;
DROP POLICY IF EXISTS "Vendor operations" ON public.orders;
DROP POLICY IF EXISTS "Rider operations" ON public.orders;
DROP POLICY IF EXISTS "Customer view" ON public.orders;
DROP POLICY IF EXISTS "Admin oversight" ON public.orders;

-- VENDOR ACCESS: Can see and update orders assigned to their kitchen
CREATE POLICY "Vendor operations" 
ON public.orders FOR ALL 
USING (
    EXISTS (
        SELECT 1 FROM public.vendors v 
        WHERE v.id::text = public.orders.vendor_id::text 
        AND v.owner_id::text = auth.uid()::text
    )
);

-- RIDER ACCESS: Can see READY orders (to claim) and update their assigned orders
CREATE POLICY "Rider operations" 
ON public.orders FOR ALL 
USING (
    (status IN ('ready', 'READY') AND rider_id IS NULL) OR 
    (rider_id::text = auth.uid()::text)
);

-- CUSTOMER ACCESS: Can see their own orders
CREATE POLICY "Customer view" 
ON public.orders FOR SELECT 
USING (customer_id::text = auth.uid()::text);

-- ADMIN ACCESS: Global bypass for authenticated users
CREATE POLICY "Admin oversight" 
ON public.orders FOR ALL 
TO authenticated 
USING (true);

-- 3. SYNC RIDER STATUS LOGIC
CREATE OR REPLACE FUNCTION sync_rider_status() 
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.is_online = TRUE THEN
        NEW.status := 'Online';
    ELSE
        NEW.status := 'Offline';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_rider_status ON public.delivery_riders;
CREATE TRIGGER trg_sync_rider_status
BEFORE INSERT OR UPDATE OF is_online ON public.delivery_riders
FOR EACH ROW EXECUTE FUNCTION sync_rider_status();

-- 4. VENDOR REAL-TIME IDENTITY FIX
ALTER TABLE public.vendors REPLICA IDENTITY FULL;
ALTER TABLE public.orders REPLICA IDENTITY FULL;
ALTER TABLE public.delivery_riders REPLICA IDENTITY FULL;

-- 5. RE-ENABLE REAL-TIME SUBSCRIPTIONS
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        CREATE PUBLICATION supabase_realtime;
    END IF;
END $$;

DO $$
DECLARE
    tbl_name TEXT;
    target_tables TEXT[] := ARRAY['orders', 'vendors', 'delivery_riders', 'notifications'];
BEGIN
    FOREACH tbl_name IN ARRAY target_tables LOOP
        BEGIN
            EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', tbl_name);
        EXCEPTION WHEN OTHERS THEN 
            RAISE NOTICE 'Table % already in publication or does not exist', tbl_name;
        END;
    END LOOP;
END $$;

COMMIT;

NOTIFY pgrst, 'reload schema';
