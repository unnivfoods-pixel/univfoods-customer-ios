-- 🏆 LOCATION & TRACKING MASTER ARCHITECTURE (V16)
-- 🧠 THE TRUTH PROTOCOL: GEOSPATIAL & REALTIME
-- Purpose: Implement 15KM radius filtering, Live GPS tracking, and Order-based Chat.

BEGIN;

-- ==========================================================
-- 📍 1. VENDOR DATA ENHANCEMENT (Geo-Lock)
-- ==========================================================
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION;
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS is_open BOOLEAN DEFAULT TRUE;
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS delivery_radius_km DOUBLE PRECISION DEFAULT 15.0;

-- Indexing for Geospatial performance (Simplified Haversine optimization)
CREATE INDEX IF NOT EXISTS idx_vendor_location ON public.vendors(latitude, longitude) WHERE is_active = TRUE AND is_open = TRUE;

-- ==========================================================
-- 📍 2. CUSTOMER ACTIVE LOCATION (Temporary State Persistence)
-- ==========================================================
-- Stores the currently active location (GPS or searched address) for the user session
CREATE TABLE IF NOT EXISTS public.active_delivery_locations (
    user_id TEXT PRIMARY KEY,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    address_line TEXT,
    city TEXT,
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.active_delivery_locations REPLICA IDENTITY FULL;

-- ==========================================================
-- 📍 3. GEOSPATIAL FILTER LOGIC (Haversine)
-- ==========================================================
CREATE OR REPLACE FUNCTION public.get_nearby_vendors_v16(
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION,
    p_max_dist_km DOUBLE PRECISION DEFAULT 15.0
)
RETURNS TABLE (
    id UUID,
    name TEXT,
    cuisine_type TEXT,
    rating DOUBLE PRECISION,
    banner_url TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    distance_km DOUBLE PRECISION,
    is_open BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        v.id::UUID as id, 
        v.name::TEXT as name, 
        v.cuisine_type::TEXT as cuisine_type, 
        v.rating::DOUBLE PRECISION as rating, 
        v.banner_url::TEXT as banner_url, 
        v.latitude::DOUBLE PRECISION as latitude, 
        v.longitude::DOUBLE PRECISION as longitude,
        (
            6371 * acos(
                cos(radians(p_lat)) * cos(radians(v.latitude)) * 
                cos(radians(v.longitude) - radians(p_lng)) + 
                sin(radians(p_lat)) * sin(radians(v.latitude))
            )
        )::DOUBLE PRECISION AS distance_km,
        v.is_open::BOOLEAN as is_open
    FROM public.vendors v
    WHERE v.is_active = TRUE
      AND (
            6371 * acos(
                cos(radians(p_lat)) * cos(radians(v.latitude)) * 
                cos(radians(v.longitude) - radians(p_lng)) + 
                sin(radians(p_lat)) * sin(radians(v.latitude))
            )
        ) <= COALESCE(v.delivery_radius_km, p_max_dist_km)
    ORDER BY distance_km ASC;
END;
$$ LANGUAGE plpgsql STABLE;

-- ==========================================================
-- 📍 4. LIVE GPS TRACKING (Realtime Rider Stream)
-- ==========================================================
CREATE TABLE IF NOT EXISTS public.delivery_live_location (
    delivery_id TEXT PRIMARY KEY,
    order_id UUID,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    heading DOUBLE PRECISION DEFAULT 0,
    speed DOUBLE PRECISION DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.delivery_live_location REPLICA IDENTITY FULL;

-- ==========================================================
-- 💬 5. REALTIME CHAT (Order Specific)
-- ==========================================================
CREATE TABLE IF NOT EXISTS public.chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES public.orders(id) ON DELETE CASCADE,
    sender_id TEXT NOT NULL,
    sender_role TEXT NOT NULL, -- 'customer', 'delivery', 'vendor'
    message TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.chat_messages REPLICA IDENTITY FULL;
CREATE INDEX IF NOT EXISTS idx_chat_order ON public.chat_messages(order_id);

-- ==========================================================
-- 🛡️ 6. REJECTION SAFETY LOGIC (Pre-Order Checks)
-- ==========================================================
CREATE OR REPLACE FUNCTION public.place_order_v4(
    p_customer_id TEXT,
    p_vendor_id UUID,
    p_items JSONB,
    p_total DOUBLE PRECISION,
    p_address TEXT,
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION,
    p_payment_method TEXT DEFAULT 'COD',
    p_instructions TEXT DEFAULT '',
    p_address_id UUID DEFAULT NULL,
    p_payment_status TEXT DEFAULT 'PENDING',
    p_payment_id TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_order_id UUID;
    v_v_lat DOUBLE PRECISION;
    v_v_lng DOUBLE PRECISION;
    v_v_radius DOUBLE PRECISION;
    v_v_status TEXT;
    v_is_open BOOLEAN;
    v_dist DOUBLE PRECISION;
BEGIN
    -- A. Fetch Vendor Stats
    SELECT latitude, longitude, COALESCE(delivery_radius_km, 15.0), status, is_open 
    INTO v_v_lat, v_v_lng, v_v_radius, v_v_status, v_is_open
    FROM public.vendors WHERE id = p_vendor_id;

    -- B. Validate Vendor Status & Open Hours
    IF v_v_status != 'ONLINE' OR v_is_open = FALSE THEN
        RAISE EXCEPTION 'VENDOR_OFFLINE: This restaurant is currently not accepting orders.';
    END IF;

    -- C. Validate Distance (Safety Check / Location Lock)
    -- Using Haversine directly for precision in function
    v_dist := 6371 * acos(
        cos(radians(p_lat)) * cos(radians(v_v_lat)) * 
        cos(radians(v_v_lng) - radians(p_lng)) + 
        sin(radians(p_lat)) * sin(radians(v_v_lat))
    );

    IF v_dist > v_v_radius THEN
        RAISE EXCEPTION 'OUT_OF_RADIUS: Selected address is %km away. Max allowed is %km.', 
            ROUND(v_dist::numeric, 2), v_v_radius;
    END IF;

    -- D. Create Order (LOCATION LOCK: delivery_lat/lng stored permanently)
    INSERT INTO public.orders (
        customer_id, vendor_id, items, total, address, 
        delivery_lat, delivery_lng, pickup_lat, pickup_lng,
        status, payment_method, payment_status, payment_id,
        pickup_otp, delivery_otp, delivery_address_id, cooking_instructions
    ) VALUES (
        p_customer_id, p_vendor_id, p_items, p_total, p_address, 
        p_lat, p_lng, v_v_lat, v_v_lng,
        'placed', p_payment_method, p_payment_status, p_payment_id,
        lpad(floor(random() * 10000)::text, 4, '0'), 
        lpad(floor(random() * 10000)::text, 4, '0'),
        p_address_id, p_instructions
    ) RETURNING id INTO v_order_id;

    -- E. Populate Order Items (Permanent Truth)
    INSERT INTO public.order_items (order_id, product_id, name, quantity, price)
    SELECT v_order_id, (item->>'product_id')::uuid, (item->>'name'), (item->>'qty')::int, (item->>'price')::double precision
    FROM jsonb_array_elements(p_items) AS item;

    -- F. Populate Payments (Permanent Truth)
    IF p_payment_status = 'paid' OR p_payment_status = 'PAID' THEN
        INSERT INTO public.payments (order_id, user_id, payment_method, transaction_id, amount, status)
        VALUES (v_order_id, p_customer_id, p_payment_method, p_payment_id, p_total, 'SUCCESS');
    END IF;

    RETURN v_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==========================================================
-- 🔄 7. REALTIME STATUS BROADCAST
-- ==========================================================
-- Ensure all status updates hit the realtime stream
ALTER TABLE public.orders REPLICA IDENTITY FULL;

CREATE OR REPLACE FUNCTION public.update_order_status_v16(
    p_order_id UUID,
    p_status TEXT,
    p_rider_id TEXT DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    UPDATE public.orders SET 
        status = p_status,
        rider_id = COALESCE(p_rider_id, rider_id),
        updated_at = now()
    WHERE id = p_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==========================================================
-- 🔄 8. MASTER GPS UPDATE (Rider Side)
-- ==========================================================
CREATE OR REPLACE FUNCTION public.update_delivery_location_v16(
    p_order_id UUID,
    p_rider_id TEXT,
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION,
    p_speed DOUBLE PRECISION DEFAULT 0,
    p_heading DOUBLE PRECISION DEFAULT 0
)
RETURNS VOID AS $$
BEGIN
    -- 1. Update Live Location Table (Primary Realtime source)
    INSERT INTO public.delivery_live_location (
        delivery_id, order_id, latitude, longitude, heading, speed, updated_at
    ) VALUES (
        p_rider_id, p_order_id, p_lat, p_lng, p_heading, p_speed, now()
    )
    ON CONFLICT (delivery_id) DO UPDATE SET
        order_id = EXCLUDED.order_id,
        latitude = EXCLUDED.latitude,
        longitude = EXCLUDED.longitude,
        heading = EXCLUDED.heading,
        speed = EXCLUDED.speed,
        updated_at = now();

    -- 2. Performance: Update the delivery_rider's general location for assignment logic
    UPDATE public.delivery_riders SET
        last_lat = p_lat,
        last_lng = p_lng,
        last_active_at = now()
    WHERE id = p_rider_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
