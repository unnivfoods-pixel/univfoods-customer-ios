-- ==========================================================
-- 📍 STRICT 15KM RADIUS ENFORCEMENT ENGINE
-- ==========================================================
-- This script enforces the 15km delivery radius at the database level.
-- It works even if the frontend attempts to bypass validation.

BEGIN;

-- 1. Ensure PostGIS is enabled
CREATE EXTENSION IF NOT EXISTS postgis;

-- 2. Ensure Vendors table has Geography column and it's synced
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS location GEOGRAPHY(POINT);

CREATE OR REPLACE FUNCTION public.sync_vendor_geography()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
        NEW.location := ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326)::geography;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_vendor_geography ON public.vendors;
CREATE TRIGGER trg_sync_vendor_geography
BEFORE INSERT OR UPDATE OF latitude, longitude ON public.vendors
FOR EACH ROW EXECUTE PROCEDURE public.sync_vendor_geography();

-- Update existing vendors to ensure they have location geography
UPDATE public.vendors 
SET location = ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography
WHERE latitude IS NOT NULL AND longitude IS NOT NULL AND location IS NULL;

-- 3. VALIDATION FUNCTION (Used by RPC and Triggers)
CREATE OR REPLACE FUNCTION public.calculate_distance_km(
    lat1 DOUBLE PRECISION, lon1 DOUBLE PRECISION,
    lat2 DOUBLE PRECISION, lon2 DOUBLE PRECISION
) RETURNS DOUBLE PRECISION AS $$
BEGIN
    RETURN ST_Distance(
        ST_SetSRID(ST_MakePoint(lon1, lat1), 4326)::geography,
        ST_SetSRID(ST_MakePoint(lon2, lat2), 4326)::geography
    ) / 1000.0;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- 4. OVERHAUL NEARBY VENDORS RPC
CREATE OR REPLACE FUNCTION public.get_nearby_vendors_v2(
    customer_lat DOUBLE PRECISION,
    customer_lng DOUBLE PRECISION
)
RETURNS TABLE (
    id UUID,
    name TEXT,
    address TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    delivery_radius_km DOUBLE PRECISION,
    status TEXT,
    distance_km DOUBLE PRECISION,
    rating NUMERIC,
    cuisine_type TEXT,
    image_url TEXT,
    banner_url TEXT,
    delivery_time TEXT,
    is_pure_veg BOOLEAN,
    has_offers BOOLEAN,
    is_busy BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        v.id,
        v.name,
        v.address,
        v.latitude,
        v.longitude,
        COALESCE(v.delivery_radius_km, 15.0),
        v.status,
        public.calculate_distance_km(customer_lat, customer_lng, v.latitude, v.longitude) AS distance_km,
        v.rating,
        v.cuisine_type,
        v.image_url,
        v.banner_url,
        v.delivery_time,
        v.is_pure_veg,
        COALESCE(v.has_offers, FALSE),
        COALESCE(v.is_busy, FALSE)
    FROM public.vendors v
    WHERE 
        v.status = 'ONLINE'
        AND v.latitude IS NOT NULL 
        AND v.longitude IS NOT NULL
        -- STRICT 15KM LIMIT
        AND public.calculate_distance_km(customer_lat, customer_lng, v.latitude, v.longitude) <= COALESCE(v.delivery_radius_km, 15.0)
    ORDER BY distance_km ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. ORDER VALIDATION TRIGGER (CRITICAL)
-- This blocks order placement if the distance is too far.
CREATE OR REPLACE FUNCTION public.enforce_order_delivery_radius()
RETURNS TRIGGER AS $$
DECLARE
    v_vendor_lat DOUBLE PRECISION;
    v_vendor_lng DOUBLE PRECISION;
    v_radius NUMERIC;
    v_distance DOUBLE PRECISION;
BEGIN
    -- Get vendor coordinates
    SELECT latitude, longitude, COALESCE(delivery_radius_km, 15.0)
    INTO v_vendor_lat, v_vendor_lng, v_radius
    FROM public.vendors
    WHERE id = NEW.vendor_id;

    -- If no coords, we can't validate, but for safety in this "Strict" system, we block
    IF v_vendor_lat IS NULL OR v_vendor_lng IS NULL THEN
        RAISE EXCEPTION 'Vendor location not found. Cannot validate delivery radius.';
    END IF;

    -- Calculate distance using customer coords from the order table
    -- Use delivery_lat/lng if they exist, else customer_lat/lng
    v_distance := public.calculate_distance_km(
        COALESCE(NEW.delivery_lat, NEW.customer_lat), 
        COALESCE(NEW.delivery_lng, NEW.customer_lng),
        v_vendor_lat, 
        v_vendor_lng
    );

    IF v_distance > v_radius THEN
        RAISE EXCEPTION 'DELIVERY_OUT_OF_RANGE: Your location is %km away. Maximum delivery radius for this vendor is %km.', 
            ROUND(v_distance::numeric, 2), v_radius;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_enforce_order_radius ON public.orders;
CREATE TRIGGER tr_enforce_order_radius
BEFORE INSERT ON public.orders
FOR EACH ROW EXECUTE PROCEDURE public.enforce_order_delivery_radius();

-- 6. ENSURE ORDERS TABLE HAS REQUIRED COLUMNS
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS customer_lat DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS customer_lng DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS delivery_lat DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS delivery_lng DOUBLE PRECISION;

COMMIT;
