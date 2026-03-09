-- FIX TYPE MISMATCH (Specific Error 42804)
-- The error "Returned type numeric does not match expected type double precision in column 6" 
-- indicates that 'delivery_radius_km' in the table is NUMERIC, but the RPC expects DOUBLE.
-- We fix this by casting ALL numeric columns to DOUBLE PRECISION in the SELECT list.

DROP FUNCTION IF EXISTS public.get_nearby_vendors_v2(double precision, double precision);

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
BEGIN
    RETURN QUERY
    SELECT 
        v.id,
        v.name,
        v.address,
        v.latitude::DOUBLE PRECISION,
        v.longitude::DOUBLE PRECISION,
        v.delivery_radius_km::DOUBLE PRECISION, -- <--- CRITICAL FIX HERE: Explicit Cast to Double
        v.status,
        (
            6371 * acos(
                LEAST(1.0, GREATEST(-1.0, 
                    cos(radians(customer_lat)) * cos(radians(v.latitude::DOUBLE PRECISION)) *
                    cos(radians(v.longitude::DOUBLE PRECISION) - radians(customer_lng)) +
                    sin(radians(customer_lat)) * sin(radians(v.latitude::DOUBLE PRECISION))
                ))
            )
        )::DOUBLE PRECISION AS distance_km,       -- <--- CRITICAL FIX HERE: Explicit Cast to Double
        v.rating::DOUBLE PRECISION,               -- <--- CRITICAL FIX HERE: Explicit Cast to Double
        v.cuisine_type,
        v.image_url,
        v.banner_url,
        v.delivery_time,
        v.is_pure_veg,
        v.has_offers,
        v.is_busy
    FROM public.vendors v
    WHERE 
        v.status IN ('ONLINE', 'OPEN', 'ACTIVE')
        AND (v.latitude IS NOT NULL AND v.longitude IS NOT NULL)
        AND (
            6371 * acos(
                LEAST(1.0, GREATEST(-1.0, 
                    cos(radians(customer_lat)) * cos(radians(v.latitude::DOUBLE PRECISION)) *
                    cos(radians(v.longitude::DOUBLE PRECISION) - radians(customer_lng)) +
                    sin(radians(customer_lat)) * sin(radians(v.latitude::DOUBLE PRECISION))
                ))
            )
        )::DOUBLE PRECISION <= 50.0 -- Relaxed limit to 50km for visibility, checking against Double
    ORDER BY distance_km ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant Permissions again just to be sure
GRANT EXECUTE ON FUNCTION public.get_nearby_vendors_v2 TO anon, authenticated, service_role;
