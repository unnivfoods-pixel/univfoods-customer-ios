-- ?? ULTIMATE REALTIME CONNECT V23
-- 🎯 MISSION: Fix "No Change" issue by providing missing fields to the app.

BEGIN;

-- 1. Create MASTER RPC v23 with ALL FIELDS
-- This ensures the app has is_open, open_time, and close_time to render correctly.
CREATE OR REPLACE FUNCTION get_nearby_vendors_v23(p_lat DOUBLE PRECISION, p_lng DOUBLE PRECISION)
RETURNS TABLE (
    id UUID,
    name TEXT,
    cuisine_type TEXT,
    rating NUMERIC,
    banner_url TEXT,
    logo_url TEXT,
    address TEXT,
    distance_km DOUBLE PRECISION,
    delivery_time TEXT,
    is_pure_veg BOOLEAN,
    has_offers BOOLEAN,
    price_for_two NUMERIC,
    status TEXT,
    is_open BOOLEAN,
    open_time TEXT,
    close_time TEXT,
    is_busy BOOLEAN,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        v.id::UUID,
        v.name::TEXT,
        v.cuisine_type::TEXT,
        COALESCE(v.rating, 0)::NUMERIC,
        v.banner_url::TEXT,
        v.logo_url::TEXT,
        COALESCE(v.address, '')::TEXT,
        (6371 * acos(
            LEAST(1.0, GREATEST(-1.0, 
                cos(radians(p_lat)) * cos(radians(COALESCE(v.latitude, p_lat))) * 
                cos(radians(COALESCE(v.longitude, p_lng)) - radians(p_lng)) + 
                sin(radians(p_lat)) * sin(radians(COALESCE(v.latitude, p_lat)))
            ))
        ))::DOUBLE PRECISION AS d_km,
        v.delivery_time::TEXT,
        COALESCE(v.is_pure_veg, FALSE)::BOOLEAN,
        COALESCE(v.has_offers, FALSE)::BOOLEAN,
        COALESCE(v.price_for_two, 250)::NUMERIC,
        v.status::TEXT,
        COALESCE(v.is_open, TRUE)::BOOLEAN,
        v.open_time::TEXT,
        v.close_time::TEXT,
        COALESCE(v.is_busy, FALSE)::BOOLEAN,
        v.latitude::DOUBLE PRECISION,
        v.longitude::DOUBLE PRECISION
    FROM public.vendors v
    WHERE v.is_active = TRUE 
    AND v.is_verified = TRUE
    AND (6371 * acos(
        LEAST(1.0, GREATEST(-1.0, 
            cos(radians(p_lat)) * cos(radians(COALESCE(v.latitude, p_lat))) * 
            cos(radians(COALESCE(v.longitude, p_lng)) - radians(p_lng)) + 
            sin(radians(p_lat)) * sin(radians(COALESCE(v.latitude, p_lat)))
        ))
    )) <= 15.0
    ORDER BY d_km ASC;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- 2. Force Replica Identity to FULL (Ensures real-time updates carry full records)
ALTER TABLE public.vendors REPLICA IDENTITY FULL;

-- 3. Reset Realtime Publication for ALL TABLES
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

COMMIT;

SELECT 'LOGISTICS GRID V23 CONNECTED' as status;
