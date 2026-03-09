-- ==========================================================
-- 🚀 MASTER STABILIZATION V21.0 - RADIUS & STATUS ENFORCER
-- ==========================================================
-- 🎯 MISSION: Fix "operator is only a shell", "closed shop orders", and "800km distance" issues.

BEGIN;

-- 🛠 0. INFRASTRUCTURE & EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "postgis" SCHEMA public;

-- 🛠 1. NUCLEAR CLEANUP OF DEPENDENCIES
-- Drop views that block column type changes
DROP VIEW IF EXISTS public.order_details_v3 CASCADE;

-- 🛠 2. DATA TYPE UNIFICATION (THE "SHELL" FIX)
-- Ensures customer_id can handle any string ID (Firebase/Guest/Supabase)
DO $$ 
BEGIN
    -- Alter orders table
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'customer_id' AND data_type = 'uuid') THEN
        ALTER TABLE public.orders ALTER COLUMN customer_id TYPE TEXT USING customer_id::TEXT;
    END IF;

    -- Alter customer_profiles table if needed
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'customer_profiles' AND column_name = 'id' AND data_type = 'uuid') THEN
        ALTER TABLE public.customer_profiles ALTER COLUMN id TYPE TEXT USING id::TEXT;
    END IF;

    -- Alter wallets table if needed
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'wallets' AND column_name = 'user_id' AND data_type = 'uuid') THEN
        ALTER TABLE public.wallets ALTER COLUMN user_id TYPE TEXT USING user_id::TEXT;
    END IF;
END $$;

-- 🛠 3. DISTANCE CALCULATION ENGINE
DROP FUNCTION IF EXISTS public.calculate_distance_km(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION);
CREATE OR REPLACE FUNCTION public.calculate_distance_km(
    lat1 DOUBLE PRECISION, lon1 DOUBLE PRECISION,
    lat2 DOUBLE PRECISION, lon2 DOUBLE PRECISION
) RETURNS DOUBLE PRECISION AS $$
BEGIN
    -- Use geography for precise KM calculation
    RETURN ST_Distance(
        ST_SetSRID(ST_MakePoint(lon1, lat1), 4326)::geography,
        ST_SetSRID(ST_MakePoint(lon2, lat2), 4326)::geography
    ) / 1000.0;
EXCEPTION WHEN OTHERS THEN
    -- Fallback to Haversine if PostGIS fails
    RETURN 6371 * acos(
        LEAST(1.0, GREATEST(-1.0, 
            cos(radians(lat1)) * cos(radians(lat2)) *
            cos(radians(lon2) - radians(lon1)) +
            sin(radians(lat1)) * sin(radians(lat2))
        ))
    );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- 🛠 3.5 DYNAMIC TIME-BASED OPEN/CLOSE LOGIC (IST)
-- Checks both the manual 'is_open' flag AND the business hours.
CREATE OR REPLACE FUNCTION public.is_vendor_open_logic(p_vendor_id UUID)
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
    SELECT is_open, status, open_time, close_time INTO v_vendor FROM public.vendors WHERE id = p_vendor_id;
    
    -- 1. Manual Override Check
    IF NOT COALESCE(v_vendor.is_open, false) OR v_vendor.status = 'OFFLINE' THEN
        RETURN FALSE;
    END IF;

    -- 2. Time-Based Check (Asia/Kolkata)
    IF v_vendor.open_time IS NULL OR v_vendor.close_time IS NULL THEN
        RETURN TRUE; -- Assume open if no hours set
    END IF;

    v_now := NOW() AT TIME ZONE 'Asia/Kolkata';
    v_now_time := (EXTRACT(HOUR FROM v_now) * 100 + EXTRACT(MINUTE FROM v_now))::INT;

    -- Parse "HH:MM" -> HHMM
    v_open_time := (SPLIT_PART(v_vendor.open_time, ':', 1)::INT * 100) + SPLIT_PART(v_vendor.open_time, ':', 2)::INT;
    v_close_time := (SPLIT_PART(v_vendor.close_time, ':', 1)::INT * 100) + SPLIT_PART(v_vendor.close_time, ':', 2)::INT;

    -- Handle overnight hours (e.g., 22:00 to 02:00)
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
    RETURN TRUE; -- Safe fallback to manual flag on error
END;
$$;

-- 🛠 4. NEARBY VENDORS RPC (v21) - REALTIME TIME-BASED FILTERING
DROP FUNCTION IF EXISTS public.get_nearby_vendors_v21(JSONB);
CREATE OR REPLACE FUNCTION public.get_nearby_vendors_v21(p_params JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_lat DOUBLE PRECISION;
    v_lng DOUBLE PRECISION;
    v_max_radius DOUBLE PRECISION := 15.0;
BEGIN
    v_lat := (p_params->>'lat')::DOUBLE PRECISION;
    v_lng := (p_params->>'lng')::DOUBLE PRECISION;

    IF v_lat IS NULL OR v_lng IS NULL OR (v_lat = 0 AND v_lng = 0) THEN
        RETURN '[]'::jsonb;
    END IF;

    RETURN (
        SELECT COALESCE(jsonb_agg(v_row), '[]'::jsonb)
        FROM (
            SELECT 
                v.*,
                public.calculate_distance_km(v_lat, v_lng, v.latitude, v.longitude) AS distance_km
            FROM public.vendors v
            WHERE 
                v.is_verified = TRUE
                AND v.is_active = TRUE
                AND public.is_vendor_open_logic(v.id) = TRUE -- 🔥 Dynamic Time-Based Check
                AND v.latitude IS NOT NULL 
                AND v.longitude IS NOT NULL
                AND public.calculate_distance_km(v_lat, v_lng, v.latitude, v.longitude) <= COALESCE(v.delivery_radius_km, v_max_radius)
            ORDER BY distance_km ASC
        ) v_row
    );
END;
$$;

-- 🛠 5. ORDER PLACEMENT RPC (v21) - NUCLEAR GUARD
DROP FUNCTION IF EXISTS public.place_order_v21(JSONB);
CREATE OR REPLACE FUNCTION public.place_order_v21(p_params JSONB)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_order_id UUID;
    v_customer_id TEXT;
    v_vendor_id UUID;
    v_lat DOUBLE PRECISION;
    v_lng DOUBLE PRECISION;
    v_total DOUBLE PRECISION;
    v_vlat DOUBLE PRECISION;
    v_vlng DOUBLE PRECISION;
    v_vrad DOUBLE PRECISION;
    v_dist DOUBLE PRECISION;
    v_is_active BOOLEAN;
    v_is_verified BOOLEAN;
    v_is_open BOOLEAN;
BEGIN
    -- Extract values
    v_customer_id := p_params->>'customer_id';
    v_vendor_id := (p_params->>'vendor_id')::UUID;
    v_lat := (p_params->>'lat')::DOUBLE PRECISION;
    v_lng := (p_params->>'lng')::DOUBLE PRECISION;
    v_total := (p_params->>'total')::DOUBLE PRECISION;

    -- 1. FETCH VENDOR DATA
    SELECT latitude, longitude, COALESCE(delivery_radius_km, 15.0), is_active, is_verified
    INTO v_vlat, v_vlng, v_vrad, v_is_active, v_is_verified
    FROM public.vendors WHERE id = v_vendor_id;

    -- 2. STATUS BLOCKS
    IF NOT public.is_vendor_open_logic(v_vendor_id) THEN
        RAISE EXCEPTION 'SHOP_CLOSED: This shop is currently closed or outside business hours.';
    END IF;
    
    IF NOT COALESCE(v_is_active, false) OR NOT COALESCE(v_is_verified, false) THEN
        RAISE EXCEPTION 'SHOP_INACTIVE: This shop is currently not verified or inactive.';
    END IF;

    -- 3. DISTANCE BLOCK
    IF v_lat IS NULL OR v_lng IS NULL OR v_vlat IS NULL OR v_vlng IS NULL THEN
        RAISE EXCEPTION 'MISSING_COORDINATES: Location data missing for order verification.';
    END IF;

    v_dist := public.calculate_distance_km(v_lat, v_lng, v_vlat, v_vlng);
    
    IF v_dist > v_vrad THEN
        RAISE EXCEPTION 'OUT_OF_RADIUS: Your selected address (%km) is too far. Limit: %km.', 
            ROUND(v_dist::numeric, 2), v_vrad;
    END IF;

    -- 4. INSERT ORDER WITH SNAPSHOT
    INSERT INTO public.orders (
        customer_id,
        vendor_id,
        items,
        total_amount,
        status,
        payment_method,
        delivery_address,
        delivery_address_text,
        delivery_pincode,
        delivery_phone,
        delivery_lat,
        delivery_lng
    ) VALUES (
        v_customer_id,
        v_vendor_id,
        p_params->'items',
        v_total,
        CASE WHEN p_params->>'payment_method' = 'UPI' THEN 'PAYMENT_PENDING' ELSE 'PLACED' END,
        p_params->>'payment_method',
        p_params->>'address',
        p_params->>'address',
        p_params->>'pincode',
        p_params->>'customer_phone',
        v_lat,
        v_lng
    ) RETURNING id INTO v_order_id;

    RETURN v_order_id;
END;
$$;

-- 🛠 6. RESTORE THE VIEW (POLISHED VERSION)
CREATE OR REPLACE VIEW public.order_details_v3 AS
SELECT 
    o.id, o.customer_id, o.vendor_id, o.rider_id, o.total_amount as total, o.status, o.items,
    o.delivery_lat, o.delivery_lng, o.delivery_address_text as delivery_address,
    o.created_at, o.payment_method,
    v.name as vendor_name, v.address as vendor_address, v.phone as vendor_phone,
    cp.full_name as customer_name, cp.phone as customer_phone
FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id = v.id
LEFT JOIN public.customer_profiles cp ON o.customer_id = cp.id;

COMMIT;
NOTIFY pgrst, 'reload schema';
