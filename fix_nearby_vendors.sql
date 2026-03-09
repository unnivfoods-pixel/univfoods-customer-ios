-- Drop existing function if any
DROP FUNCTION IF EXISTS get_nearby_vendors_v7;

CREATE OR REPLACE FUNCTION get_nearby_vendors_v7(p_params JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_lat DOUBLE PRECISION;
    v_lng DOUBLE PRECISION;
    v_radius_km DOUBLE PRECISION := 15.0; -- Default 15 KM as requested
BEGIN
    -- Extract lat/lng from JSONB
    v_lat := (p_params->>'lat')::DOUBLE PRECISION;
    v_lng := (p_params->>'lng')::DOUBLE PRECISION;

    -- Return vendors filtered by Haversine distance
    RETURN (
        SELECT COALESCE(jsonb_agg(v_data), '[]'::jsonb)
        FROM (
            SELECT 
                v.*,
                -- Haversine formula for distance in KM
                (6371 * acos(
                    LEAST(1.0, GREATEST(-1.0, 
                        cos(radians(v_lat)) * cos(radians(v.latitude)) * 
                        cos(radians(v.longitude) - radians(v_lng)) + 
                        sin(radians(v_lat)) * sin(radians(v.latitude))
                    ))
                )) AS distance_km
            FROM vendors v
            WHERE 
                v.is_active = true 
                AND v.is_approved = true
                AND v.is_open = true
                AND v.latitude IS NOT NULL
                AND v.longitude IS NOT NULL
                AND (6371 * acos(
                    LEAST(1.0, GREATEST(-1.0, 
                        cos(radians(v_lat)) * cos(radians(v.latitude)) * 
                        cos(radians(v.longitude) - radians(v_lng)) + 
                        sin(radians(v_lat)) * sin(radians(v.latitude))
                    ))
                )) <= v_radius_km
            ORDER BY distance_km ASC
        ) v_data
    );
END;
$$;
