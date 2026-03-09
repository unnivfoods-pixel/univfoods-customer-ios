-- 📍 LOCATION MASTER SYSTEM v1.0
-- Implementation of the 10-point Location Specification

-- 1. CLASSIFIED INFRASTRUCTURE UPGRADE
ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS delivery_radius_km NUMERIC DEFAULT 15.0,
ADD COLUMN IF NOT EXISTS is_busy BOOLEAN DEFAULT false;

-- 2. STRUCTURED ADDRESS REPOSITORY (Point 1.3)
CREATE TABLE IF NOT EXISTS public.user_addresses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    label TEXT DEFAULT 'Home', -- Home, Work, Other
    address_line TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    is_default BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Ensure only one default per customer
CREATE UNIQUE INDEX IF NOT EXISTS idx_one_default_address_v2 
ON public.user_addresses (user_id) 
WHERE (is_default = true);

-- 3. NEIGHBORHOOD ENGINE (Haversine/PostGIS) (Point 2.1)
CREATE OR REPLACE FUNCTION get_nearby_vendors_v2(customer_lat DOUBLE PRECISION, customer_lng DOUBLE PRECISION)
RETURNS TABLE (
    id UUID,
    name TEXT,
    rating NUMERIC,
    distance_km DOUBLE PRECISION,
    estimated_time TEXT,
    is_open BOOLEAN,
    is_busy BOOLEAN,
    cuisine_type TEXT,
    image_url TEXT,
    is_pure_veg BOOLEAN,
    has_offers BOOLEAN
) AS $$
DECLARE
    v_global_radius NUMERIC;
BEGIN
    -- Get global radius fallback from settings
    SELECT (value->>'km')::numeric INTO v_global_radius FROM public.app_settings WHERE key = 'delivery_radius_limit';
    IF v_global_radius IS NULL THEN v_global_radius := 15.0; END IF;

    RETURN QUERY
    SELECT 
        v.id, 
        v.name, 
        v.rating,
        ST_Distance(
            v.location,
            ST_SetSRID(ST_MakePoint(customer_lng, customer_lat), 4326)::geography
        ) / 1000 AS distance_km,
        -- Point 8: Dynamic ETA Calculation
        ((15 + (ST_Distance(v.location, ST_SetSRID(ST_MakePoint(customer_lng, customer_lat), 4326)::geography) / 1000 * 5))::int || ' mins') as estimated_time,
        (v.status = 'ONLINE') as is_open,
        v.is_busy,
        v.cuisine_type,
        v.image_url,
        v.is_pure_veg,
        v.has_offers
    FROM public.vendors v
    WHERE v.status = 'ONLINE'
    AND ST_Distance(
        v.location,
        ST_SetSRID(ST_MakePoint(customer_lng, customer_lat), 4326)::geography
    ) / 1000 <= COALESCE(v.delivery_radius_km, v_global_radius)
    ORDER BY distance_km ASC
    LIMIT 50;
END;
$$ LANGUAGE plpgsql;

-- 4. CHECKOUT VALIDATION (Point 5 & 6)
-- Strict revalidation before order confirmation
CREATE OR REPLACE FUNCTION validate_order_radius(v_id UUID, c_lat DOUBLE PRECISION, c_lng DOUBLE PRECISION)
RETURNS BOOLEAN AS $$
DECLARE
    v_radius NUMERIC;
    v_dist NUMERIC;
    v_global_radius NUMERIC;
BEGIN
    -- Get global search limit
    SELECT (value->>'km')::numeric INTO v_global_radius FROM public.app_settings WHERE key = 'delivery_radius_limit';
    IF v_global_radius IS NULL THEN v_global_radius := 15.0; END IF;

    SELECT COALESCE(delivery_radius_km, v_global_radius), 
           ST_Distance(location, ST_SetSRID(ST_MakePoint(c_lng, c_lat), 4326)::geography) / 1000
    INTO v_radius, v_dist
    FROM public.vendors WHERE id = v_id;

    RETURN v_dist <= v_radius;
END;
$$ LANGUAGE plpgsql;

-- 5. DELIVERY PARTNER ASSIGNMENT LOGIC (Point 6)
CREATE OR REPLACE FUNCTION find_eligible_riders(v_id UUID)
RETURNS TABLE (rider_id UUID, distance_km DOUBLE PRECISION) AS $$
DECLARE
    v_location GEOGRAPHY;
    v_radius NUMERIC := 5.0; -- Default search radius for riders (Point 8)
BEGIN
    SELECT location INTO v_location FROM public.vendors WHERE id = v_id;
    
    RETURN QUERY
    SELECT 
        r.id,
        ST_Distance(
            ST_SetSRID(ST_MakePoint(r.current_lng, r.current_lat), 4326)::geography,
            v_location
        ) / 1000 as distance_m
    FROM public.delivery_riders r
    WHERE r.is_online = true 
    AND r.active_order_id IS NULL
    AND ST_Distance(
        ST_SetSRID(ST_MakePoint(r.current_lng, r.current_lat), 4326)::geography,
        v_location
    ) / 1000 <= v_radius
    ORDER BY distance_m ASC;
END;
$$ LANGUAGE plpgsql;

-- 6. REALTIME REFRESH (Point 10)
DO $$
BEGIN
    -- Check if the publication is NOT "FOR ALL TABLES" before trying to add
    IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime' AND puballtables = true) THEN
        -- Only add if it's not already in the publication
        IF NOT EXISTS (
            SELECT 1 FROM pg_publication_tables 
            WHERE pubname = 'supabase_realtime' 
            AND schemaname = 'public' 
            AND tablename = 'user_addresses'
        ) THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.user_addresses;
        END IF;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Skipping publication update: %', SQLERRM;
END $$;
