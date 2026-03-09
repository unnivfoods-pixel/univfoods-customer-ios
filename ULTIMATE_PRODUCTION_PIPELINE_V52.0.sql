
-- ULTIMATE PRODUCTION PIPELINE V52.0 (STABILIZER & SORTING)
-- This script fixes profile uniqueness and ensures the home screen view supports sorting by distance/rating/price.

-- 1. FIX CUSTOMER PROFILES UNIQUENESS
-- Ensure 'id' is a primary key or has a unique constraint.
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conrelid = 'customer_profiles'::regclass AND contype = 'p'
    ) THEN
        -- If no PK, try to add one. If there are duplicates, we need to clean them first.
        DELETE FROM customer_profiles a USING customer_profiles b 
        WHERE a.ctid < b.ctid AND a.id = b.id;
        
        ALTER TABLE customer_profiles ADD PRIMARY KEY (id);
    END IF;
END $$;

-- 2. ENSURE VENDORS HAVE THE NECESSARY COLUMNS FOR SORTING
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vendors' AND column_name = 'price_for_two') THEN
        ALTER TABLE vendors ADD COLUMN price_for_two NUMERIC DEFAULT 250;
    END IF;
END $$;

-- 3. UPDATE RADIAL SEARCH RPC (V18)
-- Includes price_for_two for sorting.
CREATE OR REPLACE FUNCTION get_nearby_vendors_v18(p_lat DOUBLE PRECISION, p_lng DOUBLE PRECISION)
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
    is_busy BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        v.id,
        v.name,
        v.cuisine_type,
        v.rating,
        v.banner_url,
        v.logo_url,
        v.address,
        (6371 * acos(
            cos(radians(p_lat)) * cos(radians(v.lat)) * 
            cos(radians(v.lng) - radians(p_lng)) + 
            sin(radians(p_lat)) * sin(radians(v.lat))
        )) AS distance_km,
        v.delivery_time,
        v.is_pure_veg,
        v.has_offers,
        v.price_for_two,
        v.status,
        v.is_busy
    FROM vendors v
    WHERE v.approval_status = 'APPROVED'
    ORDER BY distance_km ASC;
END;
$$ LANGUAGE plpgsql;

-- 4. ENSURE REALTIME ON VENDORS TABLE
ALTER TABLE vendors REPLICA IDENTITY FULL;
COMMENT ON TABLE vendors IS 'Real-time enabled for customer home screen sorting and filtering.';
