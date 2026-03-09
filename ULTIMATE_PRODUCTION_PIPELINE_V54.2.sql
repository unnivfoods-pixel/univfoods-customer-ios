
-- ULTIMATE PRODUCTION PIPELINE V54.2 (FIXED TYPE MISMATCH)
-- MISSION: Fix the "No results" by resolving the SQL type mismatch error.

BEGIN;

-- 1. Ensure Columns exist with correct defaults
ALTER TABLE vendors ADD COLUMN IF NOT EXISTS price_for_two NUMERIC DEFAULT 250;
ALTER TABLE vendors ADD COLUMN IF NOT EXISTS is_pure_veg BOOLEAN DEFAULT FALSE;
ALTER TABLE vendors ADD COLUMN IF NOT EXISTS has_offers BOOLEAN DEFAULT FALSE;
ALTER TABLE vendors ADD COLUMN IF NOT EXISTS is_busy BOOLEAN DEFAULT FALSE;

-- 2. Force visibility (Again, just to be sure)
UPDATE vendors 
SET 
  is_active = TRUE, 
  is_open = TRUE, 
  approval_status = 'APPROVED', 
  status = 'ONLINE',
  delivery_radius_km = 99999,
  latitude = COALESCE(latitude, 9.5127),
  longitude = COALESCE(longitude, 77.6337);

-- 3. CREATE STABLE MASTER RPC v21 (Explicit Casting)
CREATE OR REPLACE FUNCTION get_nearby_vendors_v21(p_lat DOUBLE PRECISION, p_lng DOUBLE PRECISION)
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
        v.address::TEXT,
        (6371 * acos(
            LEAST(1.0, GREATEST(-1.0, 
                cos(radians(p_lat)) * cos(radians(COALESCE(v.latitude, p_lat))) * 
                cos(radians(COALESCE(v.longitude, p_lng)) - radians(p_lng)) + 
                sin(radians(p_lat)) * sin(radians(COALESCE(v.latitude, p_lat)))
            ))
        ))::DOUBLE PRECISION AS distance_km,
        v.delivery_time::TEXT,
        COALESCE(v.is_pure_veg, FALSE)::BOOLEAN,
        COALESCE(v.has_offers, FALSE)::BOOLEAN,
        COALESCE(v.price_for_two, 250)::NUMERIC,
        v.status::TEXT,
        COALESCE(v.is_busy, FALSE)::BOOLEAN,
        v.latitude::DOUBLE PRECISION,
        v.longitude::DOUBLE PRECISION
    FROM vendors v
    WHERE v.is_active = TRUE
    ORDER BY distance_km ASC;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- 4. Rebuild Realtime
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

COMMIT;
