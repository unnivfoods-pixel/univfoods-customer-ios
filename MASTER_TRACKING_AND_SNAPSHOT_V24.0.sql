-- 🏆 MASTER TRACKING & ADDRESS SNAPSHOT (V24.0)
-- 🎯 MISSION: FIX THE "CALCULATING" MAP ERROR & PERMANENTLY SAVE EVERY ADDRESS.
-- 🎯 LOGIC: Save EVERYTHING into the order row. The tracking map will ONLY read from the order.

BEGIN;

-- 1. 🔓 UNLOCK SYSTEM
DROP VIEW IF EXISTS public.order_details_v3 CASCADE;

-- 2. 🛠️ HARDEN ORDERS TABLE (Add all snapshot columns)
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS address TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_lat DOUBLE PRECISION;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_lng DOUBLE PRECISION;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS customer_name TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS customer_phone TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_address_snapshot TEXT; -- Backwards compatibility

-- 3. 🧠 REPAIR FUNCTIONS (v5 & v6)
-- We make them both identical so no matter what version the app calls, it WORKS.

CREATE OR REPLACE FUNCTION public.place_order_v5(
    p_customer_id TEXT,
    p_vendor_id TEXT,
    p_items JSONB,
    p_total DOUBLE PRECISION,
    p_address TEXT,
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION,
    p_payment_method TEXT,
    p_instructions TEXT DEFAULT NULL,
    p_address_id TEXT DEFAULT NULL,
    p_initial_status TEXT DEFAULT 'placed'
)
RETURNS UUID AS $$
DECLARE
    v_order_id UUID;
    v_v_lat DOUBLE PRECISION;
    v_v_lng DOUBLE PRECISION;
BEGIN
    -- Get Vendor GPS for pickup
    SELECT latitude, longitude INTO v_v_lat, v_v_lng 
    FROM public.vendors WHERE id = p_vendor_id::uuid;

    INSERT INTO public.orders (
        customer_id, vendor_id, items, total, 
        address, delivery_lat, delivery_lng,
        delivery_address_snapshot, -- Save typed address here too
        pickup_lat, pickup_lng, 
        status, payment_method, payment_status,
        pickup_otp, delivery_otp, cooking_instructions
    ) VALUES (
        p_customer_id::uuid, p_vendor_id::uuid, p_items, p_total, 
        p_address, p_lat, p_lng,
        p_address,
        v_v_lat, v_v_lng, 
        p_initial_status, p_payment_method, 'pending',
        lpad(floor(random() * 10000)::text, 4, '0'), 
        lpad(floor(random() * 10000)::text, 4, '0'),
        p_instructions
    ) RETURNING id INTO v_order_id;

    RETURN v_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- v6 includes customer name/phone
CREATE OR REPLACE FUNCTION public.place_order_v6(
    p_customer_id TEXT,
    p_customer_name TEXT,
    p_customer_phone TEXT,
    p_vendor_id TEXT,
    p_items JSONB,
    p_total DOUBLE PRECISION,
    p_address TEXT,
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION,
    p_payment_method TEXT,
    p_instructions TEXT DEFAULT NULL,
    p_address_id TEXT DEFAULT NULL,
    p_initial_status TEXT DEFAULT 'placed'
)
RETURNS UUID AS $$
DECLARE
    v_order_id UUID;
    v_v_lat DOUBLE PRECISION;
    v_v_lng DOUBLE PRECISION;
BEGIN
    SELECT latitude, longitude INTO v_v_lat, v_v_lng FROM public.vendors WHERE id = p_vendor_id::uuid;

    INSERT INTO public.orders (
        customer_id, vendor_id, items, total, 
        address, delivery_lat, delivery_lng,
        customer_name, customer_phone,
        delivery_address_snapshot,
        pickup_lat, pickup_lng, 
        status, payment_method, 
        pickup_otp, delivery_otp, cooking_instructions
    ) VALUES (
        p_customer_id::uuid, p_vendor_id::uuid, p_items, p_total, 
        p_address, p_lat, p_lng,
        p_customer_name, p_customer_phone,
        p_address,
        v_v_lat, v_v_lng, 
        p_initial_status, p_payment_method, 
        lpad(floor(random() * 10000)::text, 4, '0'), 
        lpad(floor(random() * 10000)::text, 4, '0'),
        p_instructions
    ) RETURNING id INTO v_order_id;

    RETURN v_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. 🔄 THE TRACKING MASTER VIEW (v3)
-- This maps the saved snapshot columns to the exact field names the app expects.
CREATE OR REPLACE VIEW public.order_details_v3 AS
SELECT 
    o.*,
    COALESCE(o.address, o.delivery_address_snapshot) as delivery_address, 
    o.delivery_lat as destination_lat, 
    o.delivery_lng as destination_lng,
    jsonb_build_object(
        'name', v.name,
        'phone', v.phone,
        'address', v.address,
        'latitude', v.latitude,
        'longitude', v.longitude,
        'logo_url', COALESCE(v.logo_url, v.image_url)
    ) as vendors,
    (
        SELECT row_to_json(r) FROM (
            SELECT 
                dr.id, dr.name, dr.phone, dr.vehicle_number,
                ll.latitude as live_lat, ll.longitude as live_lng, ll.heading
            FROM public.delivery_riders dr
            LEFT JOIN public.delivery_live_location ll ON dr.id = ll.rider_id
            WHERE dr.id = o.rider_id
        ) r
    ) as rider_details
FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id = v.id;

GRANT SELECT ON public.order_details_v3 TO anon, authenticated, service_role;

-- 5. ⚡ RESET REALTIME PUBLICATION
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

COMMIT;

SELECT 'TRACKING SNAPSHOT V24.0 INITIALIZED - ADDRESS LOCK ENABLED' as status;
