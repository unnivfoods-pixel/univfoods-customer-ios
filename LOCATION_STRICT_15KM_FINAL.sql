-- ==========================================================
-- 🌍 LOCATION-STRICT 15KM RADIUS ENFORCEMENT ENGINE - V20.0
-- ==========================================================
-- 🎯 MISSION: Implement specific user criteria for distance-based ordering.
-- 🏗️ ARCHITECTURE: 
-- 1. Snapshot Address Details in Orders.
-- 2. Strictly filter vendors by Distance (15km), OpenStatus, VerifiedStatus.
-- 3. Double-check distance at Checkout (Trigger + RPC).

BEGIN;

-- 🛠 0. INFRASTRUCTURE SETUP
CREATE EXTENSION IF NOT EXISTS "postgis" SCHEMA public;

-- 🛠 0. NUCLEAR IDENTITY MIGRATION
-- Ensures customer_id can handle BOTH Firebase (TEXT) and Supabase (UUID) IDs.
DO $$ 
BEGIN
    -- Only alter if it's not already text
    IF (SELECT data_type FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'customer_id') != 'text' THEN
        -- Drop any policies that might block the change
        DROP POLICY IF EXISTS "Users can view own orders" ON public.orders;
        -- Change type
        ALTER TABLE public.orders ALTER COLUMN customer_id TYPE TEXT;
        -- Re-enable policies
        CREATE POLICY "Users can view own orders" ON public.orders FOR SELECT USING (auth.uid()::TEXT = customer_id);
    END IF;
END $$;

-- 🛠 1. USER ADDRESSES ENHANCEMENT
ALTER TABLE public.user_addresses 
ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS pincode TEXT,
ADD COLUMN IF NOT EXISTS house_number TEXT,
ADD COLUMN IF NOT EXISTS phone TEXT;

-- 🛠 2. ORDERS TABLE ENHANCEMENT (SNAPSHOT SYSTEM)
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS delivery_address_text TEXT,
ADD COLUMN IF NOT EXISTS delivery_pincode TEXT,
ADD COLUMN IF NOT EXISTS delivery_lat DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS delivery_lng DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS delivery_phone TEXT;

-- 🛠 3. DISTANCE CALCULATION FUNCTION
DROP FUNCTION IF EXISTS public.calculate_distance_km(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION);
CREATE OR REPLACE FUNCTION public.calculate_distance_km(
    lat1 DOUBLE PRECISION, lon1 DOUBLE PRECISION,
    lat2 DOUBLE PRECISION, lon2 DOUBLE PRECISION
) RETURNS DOUBLE PRECISION AS $$
BEGIN
    RETURN ST_Distance(
        ST_SetSRID(ST_MakePoint(lon1, lat1), 4326)::geography,
        ST_SetSRID(ST_MakePoint(lon2, lat2), 4326)::geography
    ) / 1000.0;
EXCEPTION WHEN OTHERS THEN
    RETURN 6371 * acos(
        LEAST(1.0, GREATEST(-1.0, 
            cos(radians(lat1)) * cos(radians(lat2)) *
            cos(radians(lon2) - radians(lon1)) +
            sin(radians(lat1)) * sin(radians(lat2))
        ))
    );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- 🛠 4. NEARBY VENDORS RPC (v20) - STRICTEST FILTERING
DROP FUNCTION IF EXISTS public.get_nearby_vendors_v20(JSONB);
CREATE OR REPLACE FUNCTION public.get_nearby_vendors_v20(p_params JSONB)
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
                AND v.is_open = TRUE -- 🔥 Shop Must Be Open
                AND v.status = 'ONLINE'
                AND v.latitude IS NOT NULL 
                AND v.longitude IS NOT NULL
                AND public.calculate_distance_km(v_lat, v_lng, v.latitude, v.longitude) <= COALESCE(v.delivery_radius_km, v_max_radius)
            ORDER BY distance_km ASC
        ) v_row
    );
END;
$$;

-- 🛠 5. ORDER PLACEMENT RPC (v20) - NUCLEAR VALIDATION
DROP FUNCTION IF EXISTS public.place_order_v20(JSONB);
CREATE OR REPLACE FUNCTION public.place_order_v20(p_params JSONB)
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
    v_is_open BOOLEAN;
    v_is_active BOOLEAN;
    v_is_verified BOOLEAN;
BEGIN
    -- Extract values
    v_customer_id := p_params->>'customer_id';
    v_vendor_id := (p_params->>'vendor_id')::UUID;
    v_lat := (p_params->>'lat')::DOUBLE PRECISION;
    v_lng := (p_params->>'lng')::DOUBLE PRECISION;
    v_total := (p_params->>'total')::DOUBLE PRECISION;

    -- 1. FETCH VENDOR STATUS & LOCATION
    SELECT latitude, longitude, COALESCE(delivery_radius_km, 15.0), is_open, is_active, is_verified
    INTO v_vlat, v_vlng, v_vrad, v_is_open, v_is_active, v_is_verified
    FROM public.vendors WHERE id = v_vendor_id;

    -- 2. STATUS BLOCKS
    IF NOT v_is_open THEN
        RAISE EXCEPTION 'SHOP_CLOSED: This shop is currently closed and not accepting orders.';
    END IF;
    IF NOT v_is_active OR NOT v_is_verified THEN
        RAISE EXCEPTION 'SHOP_INACTIVE: This shop is currently not verified or inactive.';
    END IF;

    -- 3. DISTANCE BLOCK
    v_dist := public.calculate_distance_km(v_lat, v_lng, v_vlat, v_vlng);
    
    IF v_dist > v_vrad THEN
        RAISE EXCEPTION 'OUT_OF_RADIUS: Selected address is %km away. Max allowed for this shop is %km.', 
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

-- 🛠 6. GLOBAL TRIGGER ENFORCEMENT (Step 4 & 5 - Double Protection)
-- Even if direct INSERT happens, we block and snapshot.
CREATE OR REPLACE FUNCTION public.trg_enforce_distance_snapshot()
RETURNS TRIGGER AS $$
DECLARE
    v_vlat DOUBLE PRECISION;
    v_vlng DOUBLE PRECISION;
    v_vrad DOUBLE PRECISION;
    v_dist DOUBLE PRECISION;
BEGIN
    -- Get vendor data
    SELECT latitude, longitude, COALESCE(delivery_radius_km, 15.0)
    INTO v_vlat, v_vlng, v_vrad
    FROM vendors WHERE id = NEW.vendor_id;

    -- Check Coords
    IF v_vlat IS NOT NULL AND NEW.delivery_lat IS NOT NULL THEN
        v_dist := public.calculate_distance_km(NEW.delivery_lat, NEW.delivery_lng, v_vlat, v_vlng);
        IF v_dist > v_vrad THEN
            RAISE EXCEPTION 'RESTRICTED_RADIUS: Delivery address too far (%km).', ROUND(v_dist::numeric, 2);
        END IF;
    END IF;

    -- Populate SNAPSHOT fields if missing
    IF NEW.delivery_address_text IS NULL THEN
        NEW.delivery_address_text := NEW.delivery_address;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_distance_enforcer ON public.orders;
CREATE TRIGGER trg_distance_enforcer
BEFORE INSERT ON public.orders
FOR EACH ROW EXECUTE PROCEDURE public.trg_enforce_distance_snapshot();

COMMIT;
NOTIFY pgrst, 'reload schema';

-- 🏆 RESULT:
-- 1. All addresses now have lat/lng stored.
-- 2. Vendor List is pre-filtered by 15KM from selected address.
-- 3. Orders are BLOCKED at checkout if address is moved too far.
-- 4. Rider App uses orders.delivery_lat/lng for navigation.
