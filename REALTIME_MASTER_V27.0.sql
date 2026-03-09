-- 🏆 REALTIME OPERATIONS MASTER ENGINE (V27.0)
-- 🎯 MISSION: Fix Realtime Order Reception, Standardize Status Flow, and Enable Dispatch.
-- 🎯 FLOW: PLACED -> ACCEPTED -> PREPARING -> READY_FOR_PICKUP -> RIDER_ASSIGNED -> PICKED_UP -> DELIVERED

BEGIN;

-- ==========================================================
-- 🔓 1. UNLOCK REALTIME & RESET PUBLICATION
-- ==========================================================
-- This ensures that every INSERT/UPDATE/DELETE is broadcasted immediately.
ALTER TABLE public.orders REPLICA IDENTITY FULL;
ALTER TABLE public.vendors REPLICA IDENTITY FULL;
ALTER TABLE public.delivery_riders REPLICA IDENTITY FULL;
ALTER TABLE public.delivery_live_location REPLICA IDENTITY FULL;
ALTER TABLE public.order_tracking REPLICA IDENTITY FULL;

-- Rebuild the publication to clear any hung subscriptions
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

-- ==========================================================
-- 🛠️ 2. THE MASTER PLACEMENT ENGINE (V6)
-- ==========================================================
-- Ensures all snapshots are created correctly.
CREATE OR REPLACE FUNCTION public.place_order_v6(
    p_customer_id TEXT,
    p_vendor_id TEXT,
    p_items JSONB,
    p_total DOUBLE PRECISION,
    p_address TEXT,
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION,
    p_payment_method TEXT,
    p_instructions TEXT DEFAULT NULL,
    p_address_id TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_order_id UUID;
    v_v_lat DOUBLE PRECISION;
    v_v_lng DOUBLE PRECISION;
    v_cust_name TEXT;
    v_cust_phone TEXT;
BEGIN
    -- 1. Fetch Vendor coordinates for pickup side
    SELECT latitude, longitude INTO v_v_lat, v_v_lng
    FROM public.vendors WHERE id = p_vendor_id::uuid;

    -- 2. Fetch Customer snapshot data
    SELECT full_name, phone INTO v_cust_name, v_cust_phone
    FROM public.customer_profiles WHERE id = p_customer_id::uuid;

    -- 3. Insert Order with Snapshot Data
    INSERT INTO public.orders (
        customer_id, 
        vendor_id, 
        items, 
        total, 
        address, 
        delivery_lat, 
        delivery_lng,
        pickup_lat, 
        pickup_lng,
        customer_name_snapshot,
        customer_phone_snapshot,
        status, 
        payment_method, 
        payment_status,
        pickup_otp, 
        delivery_otp, 
        cooking_instructions
    ) VALUES (
        p_customer_id::uuid, 
        p_vendor_id::uuid, 
        p_items, 
        p_total, 
        p_address, 
        p_lat, 
        p_lng, 
        v_v_lat, 
        v_v_lng,
        v_cust_name,
        v_cust_phone,
        'PLACED', -- Use Standardized Uppercase Status
        p_payment_method, 
        'PENDING',
        lpad(floor(random() * 10000)::text, 4, '0'), 
        lpad(floor(random() * 10000)::text, 4, '0'),
        p_instructions
    ) RETURNING id INTO v_order_id;

    RETURN v_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==========================================================
-- 🏢 3. THE UNIFIED REALTIME VIEW
-- ==========================================================
CREATE OR REPLACE VIEW public.order_details_v3 AS
SELECT 
    o.*,
    v.name as vendor_name,
    v.phone as vendor_phone,
    v.address as vendor_address,
    jsonb_build_object(
        'name', v.name,
        'address', v.address,
        'latitude', v.latitude,
        'longitude', v.longitude,
        'logo_url', COALESCE(v.image_url, v.banner_url)
    ) as vendors,
    (SELECT full_name FROM public.customer_profiles cp WHERE cp.id = o.customer_id) as profile_name
FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id = v.id;

GRANT SELECT ON public.order_details_v3 TO anon, authenticated, service_role;

-- ==========================================================
-- 🔔 4. AUTOMATIC NOTIFICATION TRIGGER
-- ==========================================================
-- When an order is placed, log it to notifications table instantly.
-- This triggers the 'notifications' realtime listener in the apps.
CREATE OR REPLACE FUNCTION public.on_order_status_change()
RETURNS TRIGGER AS $$
BEGIN
    -- Notify Vendor on New Order
    IF (TG_OP = 'INSERT' AND NEW.status = 'PLACED') THEN
        INSERT INTO public.notifications (user_id, title, message, event_type)
        SELECT owner_id, 'New Order Received!', 'You have a new order for ₹' || NEW.total, 'ORDER_PLACED'
        FROM public.vendors WHERE id = NEW.vendor_id;
    END IF;

    -- Notify Customer on Status Update
    IF (TG_OP = 'UPDATE' AND OLD.status != NEW.status) THEN
        INSERT INTO public.notifications (user_id, title, message, event_type)
        VALUES (
            NEW.customer_id, 
            'Order Update: ' || NEW.status, 
            'Your order status has changed to ' || NEW.status, 
            'ORDER_UPDATE'
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_order_status_change ON public.orders;
CREATE TRIGGER tr_order_status_change
    AFTER INSERT OR UPDATE OF status ON public.orders
    FOR EACH ROW EXECUTE FUNCTION public.on_order_status_change();

-- ==========================================================
-- 🔐 5. RELAX RLS FOR REALTIME HUB
-- ==========================================================
-- Ensure vendors can read their orders for the realtime hub to trigger.
DO $$ 
BEGIN
    ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DROP POLICY IF EXISTS "Vendors can see their orders" ON public.orders;
CREATE POLICY "Vendors can see their orders" ON public.orders
FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM public.vendors v 
        WHERE v.id = orders.vendor_id 
        AND v.owner_id = auth.uid()
    )
);

DROP POLICY IF EXISTS "Customers can see their orders" ON public.orders;
CREATE POLICY "Customers can see their orders" ON public.orders
FOR SELECT USING (customer_id = auth.uid());

COMMIT;

SELECT 'REALTIME_MASTER V27.0 DEPLOYED - SYSTEM ONLINE' as status;
