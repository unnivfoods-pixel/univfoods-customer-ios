-- ==========================================
-- FIX VENDOR STATUS AND LOCATION RPC
-- ==========================================

BEGIN;

-- 1. Normalize Vendor Statuses (Fixing the "OPEN"/"ACTIVE" vs "ONLINE" mismatch)
UPDATE public.vendors 
SET status = 'ONLINE' 
WHERE status IN ('OPEN', 'ACTIVE', 'True', 'true');

-- 2. Ensure all vendors have a valid radius (Boosting to 20km for safety)
UPDATE public.vendors 
SET delivery_radius_km = 30.0 
WHERE delivery_radius_km < 30.0 OR delivery_radius_km IS NULL;

-- 3. Ensure Sample Vendors have valid coordinates (Srivilliputhur Center)
-- Royal Curry House
UPDATE public.vendors 
SET latitude = 9.5127, longitude = 77.6337 
WHERE name ILIKE '%Royal%';

-- Univ Curry Express
UPDATE public.vendors 
SET latitude = 9.5150, longitude = 77.6350 
WHERE name ILIKE '%Univ%';

-- 4. UPDATE THE RPC FUNCTION TO BE MORE LENIENT
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
    rating DOUBLE PRECISION,
    cuisine_type TEXT,
    image_url TEXT,
    banner_url TEXT,
    delivery_time TEXT,
    is_pure_veg BOOLEAN,
    has_offers BOOLEAN,
    is_busy BOOLEAN
) AS $$
DECLARE
    v_record RECORD;
BEGIN
    RETURN QUERY
    SELECT 
        v.id,
        v.name,
        v.address,
        v.latitude,
        v.longitude,
        v.delivery_radius_km,
        v.status,
        (
            6371 * acos(
                LEAST(1.0, GREATEST(-1.0, 
                    cos(radians(customer_lat)) * cos(radians(v.latitude)) *
                    cos(radians(v.longitude) - radians(customer_lng)) +
                    sin(radians(customer_lat)) * sin(radians(v.latitude))
                ))
            )
        ) AS distance_km,
        v.rating,
        v.cuisine_type,
        v.image_url,
        v.banner_url,
        v.delivery_time,
        v.is_pure_veg,
        v.has_offers,
        v.is_busy
    FROM public.vendors v
    WHERE 
        -- Allow multiple positive status strings just in case
        v.status IN ('ONLINE', 'OPEN', 'ACTIVE')
        AND (v.latitude IS NOT NULL AND v.longitude IS NOT NULL)
        AND (
            6371 * acos(
                LEAST(1.0, GREATEST(-1.0, 
                    cos(radians(customer_lat)) * cos(radians(v.latitude)) *
                    cos(radians(v.longitude) - radians(customer_lng)) +
                    sin(radians(customer_lat)) * sin(radians(v.latitude))
                ))
            )
        ) <= (v.delivery_radius_km + 5.0) -- Add 5km buffer to the check
    ORDER BY distance_km ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
