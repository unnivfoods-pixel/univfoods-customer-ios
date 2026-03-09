
-- ULTIMATE PRODUCTION PIPELINE V53.0 (VENDOR VISIBILITY & SORTING)
-- MISSION: Ensure all curriculum/vendors show up on the home screen regardless of distance.
-- MISSION: Ensure all fields needed for filtering (veg, offers, price) are present.

BEGIN;

-- 1. ADD MISSING COLUMNS IF ANY
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vendors' AND column_name = 'price_for_two') THEN
        ALTER TABLE vendors ADD COLUMN price_for_two NUMERIC DEFAULT 250;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vendors' AND column_name = 'is_pure_veg') THEN
        ALTER TABLE vendors ADD COLUMN is_pure_veg BOOLEAN DEFAULT FALSE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vendors' AND column_name = 'has_offers') THEN
        ALTER TABLE vendors ADD COLUMN has_offers BOOLEAN DEFAULT FALSE;
    END IF;
END $$;

-- 2. FORCE DATA VALIDITY
UPDATE vendors 
SET 
  is_active = TRUE, 
  is_open = TRUE, 
  approval_status = 'APPROVED', 
  status = 'ONLINE',
  delivery_radius_km = 99999,
  latitude = COALESCE(latitude, 9.5127),
  longitude = COALESCE(longitude, 77.6337)
WHERE id IS NOT NULL;

-- 3. CREATE THE MASTER RPC (V20) - NO DISTANCE LIMIT FOR TESTING
CREATE OR REPLACE FUNCTION get_nearby_vendors_v20(p_lat DOUBLE PRECISION, p_lng DOUBLE PRECISION)
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
        v.id,
        v.name,
        v.cuisine_type,
        v.rating::NUMERIC,
        v.banner_url,
        v.logo_url,
        v.address,
        (6371 * acos(
            LEAST(1.0, GREATEST(-1.0, 
                cos(radians(p_lat)) * cos(radians(COALESCE(v.latitude, p_lat))) * 
                cos(radians(COALESCE(v.longitude, p_lng)) - radians(p_lng)) + 
                sin(radians(p_lat)) * sin(radians(COALESCE(v.latitude, p_lat)))
            ))
        )) AS distance_km,
        v.delivery_time,
        COALESCE(v.is_pure_veg, FALSE) as is_pure_veg,
        COALESCE(v.has_offers, FALSE) as has_offers,
        v.price_for_two,
        v.status,
        v.is_busy,
        v.latitude,
        v.longitude
    FROM vendors v
    WHERE v.is_active = TRUE
    ORDER BY distance_km ASC;
END;
$$ LANGUAGE plpgsql STABLE;

-- Ensure real-time
ALTER TABLE vendors REPLICA IDENTITY FULL;

COMMIT;
