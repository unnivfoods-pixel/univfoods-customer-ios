
-- ==========================================================
-- 🌍 LOCATION-STRICT 15KM RADIUS ENFORCEMENT ENGINE (V2.0)
-- ==========================================================
-- 🔧 Author: Antigravity AI
-- 🔧 Purpose: Implements the 15km distance-based ordering block.
-- 🔧 Requirement: The delivery address coordinates control everything.

BEGIN;

-- 🛠 0. INFRASTRUCTURE SETUP
CREATE EXTENSION IF NOT EXISTS "postgis" SCHEMA public;

-- 🛠 1. USER ADDRESSES ENHANCEMENT
-- Ensures addresses have all fields required for map-based delivery logic.
ALTER TABLE public.user_addresses 
ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS pincode TEXT,
ADD COLUMN IF NOT EXISTS house_number TEXT,
ADD COLUMN IF NOT EXISTS landmark TEXT,
ADD COLUMN IF NOT EXISTS phone TEXT;

-- 🛠 2. ORDERS TABLE ENHANCEMENT (SNAPSHOT SYSTEM)
-- Every order MUST store a snapshot of the delivery location.
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS delivery_address_text TEXT,
ADD COLUMN IF NOT EXISTS delivery_pincode TEXT,
ADD COLUMN IF NOT EXISTS delivery_lat DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS delivery_lng DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS delivery_phone TEXT,
ADD COLUMN IF NOT EXISTS delivery_name TEXT;

-- 🛠 3. VENDOR COORDINATES SYNC
-- Ensure vendors have a geography point for fast PostGIS queries.
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS location GEOGRAPHY(POINT);

CREATE OR REPLACE FUNCTION public.sync_vendor_geography()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
        NEW.location := ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326)::geography;
    END IF;
    -- Fallback for older schema versions
    IF NEW.lat IS NOT NULL AND NEW.lng IS NOT NULL AND NEW.latitude IS NULL THEN
        NEW.latitude := NEW.lat;
        NEW.longitude := NEW.lng;
        NEW.location := ST_SetSRID(ST_MakePoint(NEW.lng, NEW.lat), 4326)::geography;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_vendor_geography ON public.vendors;
CREATE TRIGGER trg_sync_vendor_geography
BEFORE INSERT OR UPDATE OF latitude, longitude, lat, lng ON public.vendors
FOR EACH ROW EXECUTE PROCEDURE public.sync_vendor_geography();

-- Manual sync for existing data
UPDATE public.vendors 
SET location = ST_SetSRID(ST_MakePoint(COALESCE(longitude, lng), COALESCE(latitude, lat)), 4326)::geography
WHERE (latitude IS NOT NULL OR lat IS NOT NULL) AND location IS NULL;

-- 🛠 4. CORE DISTANCE CALCULATION
CREATE OR REPLACE FUNCTION public.calculate_real_distance_km(
    lat1 DOUBLE PRECISION, lon1 DOUBLE PRECISION,
    lat2 DOUBLE PRECISION, lon2 DOUBLE PRECISION
) RETURNS DOUBLE PRECISION AS $$
BEGIN
    -- Accurate PostGIS distance calculation (returns meters, divided by 1000 for KM)
    RETURN ST_Distance(
        ST_SetSRID(ST_MakePoint(lon1, lat1), 4326)::geography,
        ST_SetSRID(ST_MakePoint(lon2, lat2), 4326)::geography
    ) / 1000.0;
EXCEPTION WHEN OTHERS THEN
    -- Haversine fallback if coords are invalid
    RETURN 6371 * acos(
        LEAST(1.0, GREATEST(-1.0, 
            cos(radians(lat1)) * cos(radians(lat2)) *
            cos(radians(lon2) - radians(lon1)) +
            sin(radians(lat1)) * sin(radians(lat2))
        ))
    );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- 🛠 5. NEARBY VENDORS RPC (STRICT 15KM)
-- Frontend sends selected_lat, selected_lng from selected address.
DROP FUNCTION IF EXISTS public.get_nearby_vendors_v5(DOUBLE PRECISION, DOUBLE PRECISION);
CREATE OR REPLACE FUNCTION public.get_nearby_vendors_v5(
    p_selected_lat DOUBLE PRECISION,
    p_selected_lng DOUBLE PRECISION
)
RETURNS TABLE (
    id UUID,
    name TEXT,
    address TEXT,
    distance_km DOUBLE PRECISION,
    delivery_radius_km DOUBLE PRECISION,
    status TEXT,
    is_open BOOLEAN,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    is_verified BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        v.id,
        v.name,
        v.address,
        public.calculate_real_distance_km(p_selected_lat, p_selected_lng, v.latitude, v.longitude) AS distance_km,
        COALESCE(v.delivery_radius_km, 15.0) as delivery_radius_km,
        v.status,
        v.is_open,
        v.latitude,
        v.longitude,
        v.is_verified
    FROM public.vendors v
    WHERE v.is_verified = TRUE
    AND v.status = 'ONLINE'
    AND v.is_open = TRUE
    AND public.calculate_real_distance_km(p_selected_lat, p_selected_lng, v.latitude, v.longitude) <= COALESCE(v.delivery_radius_km, 15.0)
    ORDER BY distance_km ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 🛠 6. DOUBLE CHECK DURING CHECKOUT (THE ENFORCER)
CREATE OR REPLACE FUNCTION public.enforce_distance_at_checkout()
RETURNS TRIGGER AS $$
DECLARE
    v_vendor_lat DOUBLE PRECISION;
    v_vendor_lng DOUBLE PRECISION;
    v_vendor_radius DOUBLE PRECISION;
    v_distance DOUBLE PRECISION;
BEGIN
    -- 1. IDENTIFY VENDOR COORDINATES
    SELECT latitude, longitude, COALESCE(delivery_radius_km, 15.0)
    INTO v_vendor_lat, v_vendor_lng, v_vendor_radius
    FROM public.vendors
    WHERE id = NEW.vendor_id;

    -- 2. VERIFY COORDS EXIST
    IF v_vendor_lat IS NULL OR v_vendor_lng IS NULL THEN
        RAISE EXCEPTION 'LOGISTICS_ERROR: Selected curry point has no map coordinates.';
    END IF;

    -- 3. VERIFY DELIVERY COORDINATES (Core Requirement)
    IF NEW.delivery_lat IS NULL OR NEW.delivery_lng IS NULL THEN
        -- Fallback to delivery_address_lat/lng if provided differently
        IF NEW.delivery_address_lat IS NOT NULL THEN
            NEW.delivery_lat := NEW.delivery_address_lat;
            NEW.delivery_lng := NEW.delivery_address_lng;
        ELSE
            RAISE EXCEPTION 'LOCATION_REQUIRED: Please select a valid delivery address on the map.';
        END IF;
    END IF;

    -- 4. CALCULATE DISTANCE
    v_distance := public.calculate_real_distance_km(
        NEW.delivery_lat, NEW.delivery_lng,
        v_vendor_lat, v_vendor_lng
    );

    -- 5. THE 15KM BLOCK
    IF v_distance > v_vendor_radius THEN
        RAISE EXCEPTION 'OUT_OF_RANGE: Delivery not available for this address. Current distance: %km. Max allowed: %km.', 
            ROUND(v_distance::numeric, 2), v_vendor_radius;
    END IF;

    -- 6. SNAPSHOT DATA (Prevent later edits from affecting this order)
    -- This ensures Rider app sees exactly what was confirmed.
    IF NEW.delivery_address_text IS NULL AND (SELECT 1 FROM user_addresses WHERE id = NEW.address_id) IS NOT NULL THEN
        SELECT address_line, pincode 
        INTO NEW.delivery_address_text, NEW.delivery_pincode
        FROM user_addresses WHERE id = NEW.address_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_enforce_distance ON public.orders;
CREATE TRIGGER trg_enforce_distance
BEFORE INSERT ON public.orders
FOR EACH ROW EXECUTE PROCEDURE public.enforce_distance_at_checkout();

-- 🛠 7. ENSURE RIDER APP SYNC
-- Compatibility view update (if exists)
CREATE OR REPLACE VIEW public.order_tracking_v2 AS
SELECT 
    o.id,
    o.status,
    o.delivery_lat,
    o.delivery_lng,
    o.delivery_address_text,
    v.name as vendor_name,
    v.latitude as vendor_lat,
    v.longitude as vendor_lng
FROM public.orders o
JOIN public.vendors v ON o.vendor_id = v.id;

-- 🛠 8. REALTIME ENABLEMENT
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    CREATE PUBLICATION supabase_realtime FOR ALL TABLES;
  ELSE
    ALTER PUBLICATION supabase_realtime ADD TABLE public.user_addresses;
    ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
  END IF;
EXCEPTION WHEN OTHERS THEN
  NULL; -- Publication might already have tables
END $$;

COMMIT;

-- 🏆 RESULT:
-- 1. Srivilliputhur shop -> Srivilliputhur delivery only (within 15km)
-- 2. Hyderabad shop -> Hyderabad delivery only (within 15km)
-- 3. Orders blocked automatically if distance > 15KM.
