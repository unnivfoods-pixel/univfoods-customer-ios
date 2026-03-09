-- ⚡ ATOMIC REALTIME SYNC (V30.0)
-- 🎯 MISSION: Resurrect "Dead" Realtime for Vendors & Dashboards.
-- 🎯 MISSION: Ensure "Pub/Sub" is active for all core operations.

BEGIN;

-- 1. REPLICA IDENTITY UPGRADE
-- This ensures that the WHOLE record is sent during real-time updates, not just the ID.
ALTER TABLE public.orders REPLICA IDENTITY FULL;
ALTER TABLE public.vendors REPLICA IDENTITY FULL;
ALTER TABLE public.customer_profiles REPLICA IDENTITY FULL;
ALTER TABLE public.user_favorites REPLICA IDENTITY FULL;
ALTER TABLE public.products REPLICA IDENTITY FULL;

-- 2. PUBLICATION REBIRTH
-- Sometimes the publication gets stuck or filters out tables. We rebuild it fresh.
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

-- 3. ENSURE VENDOR NOTIFICATIONS WORK
-- Vendors need to know when an order is placed.
ALTER TABLE public.orders SET (realtime.loglevel = 'info');

-- 4. VENDOR SEARCH RECOVERY (v17 - Explicit NULL handling)
-- Fixes "Curry Point not showing in dashboard" if location is slightly off.
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
        v.banner_url::TEXT as banner_url, 
        v.latitude::DOUBLE PRECISION as latitude, 
        v.longitude::DOUBLE PRECISION as longitude,
        (
            6371 * acos(
                p_lat * 0.017453292519943295 -- radians
            ) * 0 -- Placeholder for optimized haversine logic if needed, but we use the robust one below:
        ) * 0 + 
        (
            6371 * acos(
                LEAST(1, GREATEST(-1, 
                    cos(radians(p_lat)) * cos(radians(v.latitude)) * 
                    cos(radians(v.longitude) - radians(p_lng)) + 
                    sin(radians(p_lat)) * sin(radians(v.latitude))
                ))
            )
        )::DOUBLE PRECISION AS distance_km,
        v.is_open::BOOLEAN as is_open,
        v.status::TEXT as status,
        COALESCE(v.is_busy, false)::BOOLEAN as is_busy
    FROM public.vendors v
    WHERE v.is_active = TRUE
      AND (
            6371 * acos(
                LEAST(1, GREATEST(-1, 
                    cos(radians(p_lat)) * cos(radians(v.latitude)) * 
                    cos(radians(v.longitude) - radians(p_lng)) + 
                    sin(radians(p_lat)) * sin(radians(v.latitude))
                ))
            )
        ) <= COALESCE(v.delivery_radius_km, p_max_dist_km)
    ORDER BY distance_km ASC;
END;
$$ LANGUAGE plpgsql STABLE;

COMMIT;
