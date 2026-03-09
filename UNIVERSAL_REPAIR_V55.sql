-- ==========================================
-- 🚀 UNIVERSAL REPAIR V55: THE "SHELL" OPERATOR FIX
-- ==========================================
-- 🎯 MISSION: Resolve "operator is only a shell: text = uuid" errors.
-- 🛠️ STRATEGY: Enforce explicit ::TEXT casting for all ID comparisons.

BEGIN;

-- [1] FIX RADIUS ENFORCEMENT TRIGGER
CREATE OR REPLACE FUNCTION public.enforce_order_delivery_radius()
RETURNS TRIGGER AS $$
DECLARE
    v_vendor_lat DOUBLE PRECISION;
    v_vendor_lng DOUBLE PRECISION;
    v_radius NUMERIC;
    v_distance DOUBLE PRECISION;
BEGIN
    SELECT latitude, longitude, COALESCE(delivery_radius_km, 15.0)
    INTO v_vendor_lat, v_vendor_lng, v_radius
    FROM public.vendors
    WHERE id::text = NEW.vendor_id::text;

    IF v_vendor_lat IS NOT NULL AND (NEW.delivery_lat IS NOT NULL OR NEW.customer_lat IS NOT NULL) THEN
        v_distance := public.calculate_distance_km(
            COALESCE(NEW.delivery_lat, NEW.customer_lat), 
            COALESCE(NEW.delivery_lng, NEW.customer_lng),
            v_vendor_lat, 
            v_vendor_lng
        );

        IF v_distance > v_radius THEN
            RAISE EXCEPTION 'OUT_OF_RADIUS: Your address is %km away. Max allowed: %km.', 
                ROUND(v_distance::numeric, 2), v_radius;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- [2] FIX DISTANCE SNAPSHOT TRIGGER
CREATE OR REPLACE FUNCTION public.trg_enforce_distance_snapshot()
RETURNS TRIGGER AS $$
DECLARE
    v_vlat DOUBLE PRECISION;
    v_vlng DOUBLE PRECISION;
    v_vrad DOUBLE PRECISION;
    v_dist DOUBLE PRECISION;
BEGIN
    SELECT latitude, longitude, COALESCE(delivery_radius_km, 15.0)
    INTO v_vlat, v_vlng, v_vrad
    FROM vendors WHERE id::text = NEW.vendor_id::text;

    IF v_vlat IS NOT NULL AND NEW.delivery_lat IS NOT NULL THEN
        v_dist := public.calculate_distance_km(NEW.delivery_lat, NEW.delivery_lng, v_vlat, v_vlng);
        IF v_dist > v_vrad THEN
            RAISE EXCEPTION 'RESTRICTED_RADIUS: Delivery address too far (%km).', ROUND(v_dist::numeric, 2);
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- [3] FIX IS_VENDOR_OPEN_LOGIC
CREATE OR REPLACE FUNCTION public.is_vendor_open_logic(p_vendor_id TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_vendor RECORD;
    v_now TIMESTAMP WITH TIME ZONE;
    v_now_time INT;
    v_open_time INT;
    v_close_time INT;
BEGIN
    SELECT is_open, status, open_time, close_time INTO v_vendor FROM public.vendors WHERE id::text = p_vendor_id::text;
    
    IF NOT COALESCE(v_vendor.is_open, false) OR v_vendor.status = 'OFFLINE' THEN
        RETURN FALSE;
    END IF;

    IF v_vendor.open_time IS NULL OR v_vendor.close_time IS NULL THEN
        RETURN TRUE;
    END IF;

    v_now := NOW() AT TIME ZONE 'Asia/Kolkata';
    v_now_time := (EXTRACT(HOUR FROM v_now) * 100 + EXTRACT(MINUTE FROM v_now))::INT;

    v_open_time := (SPLIT_PART(v_vendor.open_time, ':', 1)::INT * 100) + SPLIT_PART(v_vendor.open_time, ':', 2)::INT;
    v_close_time := (SPLIT_PART(v_vendor.close_time, ':', 1)::INT * 100) + SPLIT_PART(v_vendor.close_time, ':', 2)::INT;

    IF v_close_time < v_open_time THEN
        IF v_now_time >= v_open_time OR v_now_time <= v_close_time THEN
            RETURN TRUE;
        END IF;
    ELSE
        IF v_now_time >= v_open_time AND v_now_time <= v_close_time THEN
            RETURN TRUE;
        END IF;
    END IF;

    RETURN FALSE;
EXCEPTION WHEN OTHERS THEN
    RETURN TRUE;
END;
$$;

-- [4] FIX PLACE_ORDER_V21
CREATE OR REPLACE FUNCTION public.place_order_v21(p_params JSONB)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_order_id UUID;
    v_customer_id TEXT;
    v_vendor_id TEXT;
    v_lat DOUBLE PRECISION;
    v_lng DOUBLE PRECISION;
    v_total DOUBLE PRECISION;
    v_vlat DOUBLE PRECISION;
    v_vlng DOUBLE PRECISION;
    v_vrad DOUBLE PRECISION;
    v_dist DOUBLE PRECISION;
    v_is_active BOOLEAN;
    v_is_verified BOOLEAN;
    v_init_status TEXT;
BEGIN
    v_customer_id := p_params->>'customer_id';
    v_vendor_id := p_params->>'vendor_id';
    v_lat := (p_params->>'lat')::DOUBLE PRECISION;
    v_lng := (p_params->>'lng')::DOUBLE PRECISION;
    v_total := (p_params->>'total')::DOUBLE PRECISION;

    SELECT latitude, longitude, COALESCE(delivery_radius_km, 15.0), is_active, is_verified
    INTO v_vlat, v_vlng, v_vrad, v_is_active, v_is_verified
    FROM public.vendors WHERE id::text = v_vendor_id::text;

    IF NOT public.is_vendor_open_logic(v_vendor_id) THEN
        RAISE EXCEPTION 'SHOP_CLOSED: This shop is currently closed.';
    END IF;
    
    IF NOT COALESCE(v_is_active, false) OR NOT COALESCE(v_is_verified, false) THEN
        RAISE EXCEPTION 'SHOP_INACTIVE: This shop is currently not active.';
    END IF;

    IF v_lat IS NOT NULL AND v_vlat IS NOT NULL THEN
        v_dist := public.calculate_distance_km(v_lat, v_lng, v_vlat, v_vlng);
        IF v_dist > v_vrad THEN
            RAISE EXCEPTION 'OUT_OF_RADIUS: Selected address (%km) is too far. Limit: %km.', 
                ROUND(v_dist::numeric, 2), v_vrad;
        END IF;
    END IF;

    v_init_status := CASE WHEN p_params->>'payment_method' = 'UPI' THEN 'PAYMENT_PENDING' ELSE 'PLACED' END;

    INSERT INTO public.orders (
        customer_id, vendor_id, items, total_amount, status, order_status, payment_method,
        delivery_address, delivery_address_text, delivery_pincode, delivery_phone,
        delivery_lat, delivery_lng, created_at
    ) VALUES (
        v_customer_id, v_vendor_id, p_params->'items', v_total, v_init_status, v_init_status,
        p_params->>'payment_method', p_params->>'address', p_params->>'address',
        p_params->>'pincode', p_params->>'customer_phone', v_lat, v_lng, now()
    ) RETURNING id INTO v_order_id;

    RETURN v_order_id;
END;
$$;

-- [5] FIX PLACE_ORDER_STABILIZED_V4
CREATE OR REPLACE FUNCTION public.place_order_stabilized_v4(
    p_customer_id TEXT,
    p_vendor_id TEXT,
    p_items JSONB,
    p_total DOUBLE PRECISION,
    p_address TEXT,
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION,
    p_payment_method TEXT DEFAULT 'COD',
    p_instructions TEXT DEFAULT '',
    p_address_id TEXT DEFAULT NULL,
    p_payment_status TEXT DEFAULT 'PENDING',
    p_payment_id TEXT DEFAULT NULL
)
RETURNS TEXT AS $$
DECLARE
    v_order_id TEXT;
    v_initial_status TEXT;
BEGIN
    IF p_payment_method != 'COD' AND p_payment_status != 'SUCCESS' THEN
        v_initial_status := 'PAYMENT_PENDING';
    ELSE
        v_initial_status := 'PLACED';
    END IF;

    INSERT INTO public.orders (
        customer_id, vendor_id, items, total_amount, delivery_address, 
        delivery_lat, delivery_lng, 
        status, order_status, payment_method, payment_status, payment_id,
        cooking_instructions, created_at
    ) VALUES (
        p_customer_id, p_vendor_id, p_items, p_total, p_address, 
        p_lat, p_lng,
        v_initial_status, v_initial_status, p_payment_method, p_payment_status, p_payment_id,
        p_instructions, now()
    ) RETURNING id::text INTO v_order_id;

    RETURN v_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- [6] RE-SYNC VIEWS
DROP VIEW IF EXISTS public.order_details_v3 CASCADE;
CREATE OR REPLACE VIEW public.order_details_v3 AS
SELECT 
    o.*,
    v.name as vendor_name,
    v.address as live_vendor_address,
    v.image_url as vendor_logo_url,
    cp.full_name as profile_customer_name,
    cp.phone as profile_customer_phone,
    o.customer_name_snapshot as snapshot_customer_name,
    o.customer_phone_snapshot as snapshot_customer_phone
FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id::text = v.id::text
LEFT JOIN public.customer_profiles cp ON o.customer_id::text = cp.id::text;

DROP VIEW IF EXISTS public.view_customer_orders CASCADE;
CREATE OR REPLACE VIEW public.view_customer_orders AS
SELECT 
    o.*,
    v.name as vendor_name,
    v.address as live_vendor_address,
    v.image_url as vendor_logo,
    dr.name as rider_name,
    dr.phone as rider_phone,
    dr.vehicle_number as rider_vehicle,
    dr.current_lat as live_rider_lat,
    dr.current_lng as live_rider_lng
FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id::text = v.id::text
LEFT JOIN public.delivery_riders dr ON o.rider_id::text = dr.id::text;

COMMIT;

-- RELOAD SCHEMA
NOTIFY pgrst, 'reload schema';
