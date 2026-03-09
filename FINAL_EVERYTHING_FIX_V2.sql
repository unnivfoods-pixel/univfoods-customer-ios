-- 🛰️ ABSOLUTE REPAIR: REAL DISTANCE + SAVING LOGIC
-- 1. Fix get_nearby_vendors_v7 (15KM Radius & Real Math)
-- 2. Add admin helper for distance calculation

BEGIN;

-- 🛡️ 1. VENDOR FETCHING WITH REAL HAVERSINE
CREATE OR REPLACE FUNCTION public.get_nearby_vendors_v7(p_params JSONB)
RETURNS JSONB AS $$
DECLARE 
    v_lat DOUBLE PRECISION;
    v_lng DOUBLE PRECISION;
    result JSONB;
BEGIN
    v_lat := (p_params->>'lat')::DOUBLE PRECISION;
    v_lng := (p_params->>'lng')::DOUBLE PRECISION;

    SELECT jsonb_agg(sub) INTO result FROM (
        SELECT 
            v.id, 
            v.name, 
            v.latitude as lat, 
            v.longitude as lng, 
            -- Calculate REAL distance in KM
            (6371 * acos(
                LEAST(1.0, GREATEST(-1.0, 
                    cos(radians(v_lat)) * cos(radians(v.latitude)) * 
                    cos(radians(v.longitude) - radians(v_lng)) + 
                    sin(radians(v_lat)) * sin(radians(v.latitude))
                ))
            ))::DOUBLE PRECISION as distance_km,
            COALESCE(v.rating, 4.5)::DOUBLE PRECISION as rating, 
            COALESCE(v.cuisine_type, 'Premium Indian')::TEXT as cuisine_type, 
            COALESCE(v.price_for_two::TEXT, '200') as price_for_two, 
            '25 min'::TEXT as delivery_time, 
            COALESCE(v.banner_url, v.image_url, 'https://images.unsplash.com/photo-1512132411229-c30391241dd8')::TEXT as banner_url,
            COALESCE(v.is_pure_veg, false) as is_pure_veg,
            true as has_offers,
            v.is_open
        FROM public.vendors v
        WHERE v.is_active = TRUE 
        AND v.is_approved = TRUE
        AND v.latitude IS NOT NULL
        AND v.longitude IS NOT NULL
        -- Only show vendors within 15 KM
        AND (6371 * acos(
                LEAST(1.0, GREATEST(-1.0, 
                    cos(radians(v_lat)) * cos(radians(v.latitude)) * 
                    cos(radians(v.longitude) - radians(v_lng)) + 
                    sin(radians(v_lat)) * sin(radians(v.latitude))
                ))
            )) <= 15.0
        ORDER BY (6371 * acos(
                LEAST(1.0, GREATEST(-1.0, 
                    cos(radians(v_lat)) * cos(radians(v.latitude)) * 
                    cos(radians(v.longitude) - radians(v_lng)) + 
                    sin(radians(v_lat)) * sin(radians(v.latitude))
                ))
            )) ASC
    ) sub;

    RETURN COALESCE(result, '[]'::JSONB);
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- 🛡️ 2. ADMIN HELPER: GET DISTANCE BETWEEN ANY TWO POINTS
CREATE OR REPLACE FUNCTION public.calculate_distance_km(lat1 DOUBLE PRECISION, lng1 DOUBLE PRECISION, lat2 DOUBLE PRECISION, lng2 DOUBLE PRECISION)
RETURNS DOUBLE PRECISION AS $$
BEGIN
    RETURN (6371 * acos(
        LEAST(1.0, GREATEST(-1.0, 
            cos(radians(lat1)) * cos(radians(lat2)) * 
            cos(radians(lng2) - radians(lng1)) + 
            sin(radians(lat1)) * sin(radians(lat2))
        ))
    ));
END; $$ LANGUAGE plpgsql IMMUTABLE;

COMMIT;
SELECT 'REAL DISTANCE + ADMIN CALCULATOR ENABLED' as status;
