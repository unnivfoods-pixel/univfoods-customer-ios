-- 🏆 PERMANENT ORDER SNAPSHOT ARCHITECTURE (V22.0)
-- 🎯 Purpose: Ensure delivery data is permanently frozen inside the order at the moment of placement.
-- 🎯 Logic: No more dependence on user profiles. The order stores the address, lat, lng, and phone forever.

BEGIN;

-- ==========================================================
-- 🛠️ 1. SCHEMA UPGRADE: THE SNAPSHOT COLUMNS
-- ==========================================================
-- We ensure the orders table has dedicated columns for the PERMANENT snapshot.
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_address_snapshot TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_lat_snapshot DOUBLE PRECISION;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_lng_snapshot DOUBLE PRECISION;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS customer_name_snapshot TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS customer_phone_snapshot TEXT;

-- Indexing for Rider App performance
CREATE INDEX IF NOT EXISTS idx_order_delivery_coords ON public.orders(delivery_lat_snapshot, delivery_lng_snapshot);

-- ==========================================================
-- 🛒 2. THE SNAPSHOT ORDER ENGINE (v6)
-- ==========================================================
-- This function takes the FULL details and freezes them into the order.
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
    -- 1. Fetch Vendor coordinates for the "Pickup" side of the snapshot
    SELECT latitude, longitude INTO v_v_lat, v_v_lng
    FROM public.vendors WHERE id = p_vendor_id::uuid;

    -- 2. Insert the order with the PERMANENT SNAPSHOT
    INSERT INTO public.orders (
        customer_id, 
        vendor_id, 
        items, 
        total, 
        address, -- Legacy field for safety
        delivery_address_snapshot, -- 📍 PERMANENT TEXT
        delivery_lat, -- Legacy field
        delivery_lng, -- Legacy field
        delivery_lat_snapshot, -- 📍 PERMANENT LAT
        delivery_lng_snapshot, -- 📍 PERMANENT LNG
        customer_name_snapshot, -- 📍 PERMANENT NAME
        customer_phone_snapshot, -- 📍 PERMANENT PHONE
        pickup_lat, 
        pickup_lng,
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
        p_address, -- Store address in snapshot
        p_lat, 
        p_lng, 
        p_lat, -- Store lat in snapshot
        p_lng, -- Store lng in snapshot
        p_customer_name, 
        p_customer_phone,
        v_v_lat, 
        v_v_lng,
        p_initial_status, 
        p_payment_method, 
        'pending',
        lpad(floor(random() * 10000)::text, 4, '0'), 
        lpad(floor(random() * 10000)::text, 4, '0'),
        p_instructions
    ) RETURNING id INTO v_order_id;

    RETURN v_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==========================================================
-- 🔄 3. THE TRUTH VIEW (v3 - Snapshot Optimized)
-- ==========================================================
-- Tracking and Rider apps MUST read from these snapshot fields.
DROP VIEW IF EXISTS public.order_details_v3 CASCADE;
CREATE OR REPLACE VIEW public.order_details_v3 AS
SELECT 
    o.*,
    -- Force the app to use the snapshot for the UI
    COALESCE(o.delivery_address_snapshot, o.address) as delivery_address, 
    COALESCE(o.delivery_lat_snapshot, o.delivery_lat) as destination_lat, 
    COALESCE(o.delivery_lng_snapshot, o.delivery_lng) as destination_lng,
    o.customer_name_snapshot as customer_display_name,
    o.customer_phone_snapshot as customer_display_phone,
    jsonb_build_object(
        'name', v.name,
        'phone', v.phone,
        'address', v.address,
        'latitude', v.latitude,
        'longitude', v.longitude
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

-- ==========================================================
-- ⚡ 4. REALTIME SYNC
-- ==========================================================
ALTER TABLE public.orders REPLICA IDENTITY FULL;
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

COMMIT;

SELECT 'PERMANENT SNAPSHOT ENGINE V22.0 INITIALIZED' as status;
