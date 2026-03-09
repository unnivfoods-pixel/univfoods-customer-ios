-- ?? REALTIME MASTER CONNECT V2
-- This script ensures everything is set to "LIVE" on the database side.

BEGIN;

-- 1. Reset Realtime Publication
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

-- 2. Set Replica Identity for vendors to FULL
-- This ensures the "status" field is sent in the update payload in Flutter.
ALTER TABLE public.vendors REPLICA IDENTITY FULL;

-- 3. Optimization: Ensure the Switch always triggers a refresh
-- Adding an index if needed (proactive)
CREATE INDEX IF NOT EXISTS idx_vendors_status ON public.vendors(status, is_open);

-- 4. RPC V22 - Strict 15km + Stable Types
-- Redefining to be sure it's the latest version.
CREATE OR REPLACE FUNCTION get_nearby_vendors_v22(p_lat DOUBLE PRECISION, p_lng DOUBLE PRECISION)
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

COMMIT;

SELECT 'LOGISTICS GRID CONNECTED (FULL REFRESH)' as status;
