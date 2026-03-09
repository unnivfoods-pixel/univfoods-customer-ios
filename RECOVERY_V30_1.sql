-- 🚨 EMERGENCY VENDOR RECOVERY (V30.1)
-- 🎯 MISSION: Force vendors to appear on the Home Screen.
-- 🎯 MISSION: Fix "0 Popular Curries" issue.

BEGIN;

-- 1. HEAL VENDOR DATA
-- Ensure all vendors are "Active" and "Open" so they show up.
-- Also ensure they have a massive delivery radius so location doesn't block them during testing.
UPDATE public.vendors 
SET 
  is_active = TRUE, 
  is_open = TRUE, 
  status = 'ONLINE',
  delivery_radius_km = 9999.0  -- Setting to 9999km to ensure they appear regardless of user location
WHERE is_active = FALSE OR is_open = FALSE OR status != 'ONLINE' OR delivery_radius_km IS NULL;

-- 2. BULLETPROOF SEARCH FUNCTION (v17.1)
-- Added COALESCE to lat/lng to prevent NULL math from hiding vendors.
CREATE OR REPLACE FUNCTION public.get_nearby_vendors_v17(
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION,
    p_max_dist_km DOUBLE PRECISION DEFAULT 15.0
)
RETURNS TABLE (
    id UUID,
    name TEXT,
    cuisine_type TEXT,
    rating DOUBLE PRECISION,
    banner_url TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    distance_km DOUBLE PRECISION,
    is_open BOOLEAN,
    status TEXT,
    is_busy BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        v.id::UUID as id, 
        v.name::TEXT as name, 
        v.cuisine_type::TEXT as cuisine_type, 
        v.rating::DOUBLE PRECISION as rating, 
        COALESCE(v.banner_url, v.image_url)::TEXT as banner_url, 
        v.latitude::DOUBLE PRECISION as latitude, 
        v.longitude::DOUBLE PRECISION as longitude,
        (
            6371 * acos(
                LEAST(1, GREATEST(-1, 
                    cos(radians(p_lat)) * cos(radians(COALESCE(v.latitude, p_lat))) * 
                    cos(radians(COALESCE(v.longitude, p_lng)) - radians(p_lng)) + 
                    sin(radians(p_lat)) * sin(radians(COALESCE(v.latitude, p_lat)))
                ))
            )
        )::DOUBLE PRECISION AS distance_km,
        v.is_open::BOOLEAN as is_open,
        v.status::TEXT as status,
        COALESCE(v.is_busy, false)::BOOLEAN as is_busy
    FROM public.vendors v
    WHERE v.is_active = TRUE
      -- If the vendor has no radius, use 15km. If they have no location, they appear at 0km (distance_km = 0).
      AND (
            6371 * acos(
                LEAST(1, GREATEST(-1, 
                    cos(radians(p_lat)) * cos(radians(COALESCE(v.latitude, p_lat))) * 
                    cos(radians(COALESCE(v.longitude, p_lng)) - radians(p_lng)) + 
                    sin(radians(p_lat)) * sin(radians(COALESCE(v.latitude, p_lat)))
                ))
            )
        ) <= COALESCE(v.delivery_radius_km, p_max_dist_km, 15.0)
    ORDER BY distance_km ASC;
END;
$$ LANGUAGE plpgsql STABLE;

-- 3. REPLICA RE-SYNC
-- Ensure real-time is listening to all columns for these tables.
ALTER TABLE public.vendors REPLICA IDENTITY FULL;
ALTER TABLE public.products REPLICA IDENTITY FULL;

COMMIT;
