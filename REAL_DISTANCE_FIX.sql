-- PRODUCTION REPAIR: TRUE DISTANCE LOGIC
-- This script REMOVES the hardcoded 0.1km and 5000km radius.
-- It implements the REAL Haversine formula for distance.

BEGIN;

CREATE OR REPLACE FUNCTION public.get_nearby_vendors_v7(p_params JSONB)
RETURNS JSONB AS $$
DECLARE 
    v_lat DOUBLE PRECISION;
    v_lng DOUBLE PRECISION;
    result JSONB;
BEGIN
    -- Extract customer location
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
            COALESCE(v.cuisine_type, 'Indian')::TEXT as cuisine_type, 
            COALESCE(v.price_for_two::TEXT, '200') as price_for_two, 
            '25 min'::TEXT as delivery_time, 
            COALESCE(v.banner_url, v.image_url, 'https://images.unsplash.com/photo-1512132411229-c30391241dd8')::TEXT as banner_url,
            COALESCE(v.is_pure_veg, false) as is_pure_veg,
            true as has_offers,
            v.is_open
        FROM public.vendors v
        WHERE v.is_active = TRUE 
        AND v.is_approved = TRUE
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

COMMIT;
SELECT 'TRUE DISTANCE REPAIR COMPLETE' as status;
