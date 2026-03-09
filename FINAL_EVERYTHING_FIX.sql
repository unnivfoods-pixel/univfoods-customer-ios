-- ==========================================
-- 🚀 THE "EVERYTHING" FIX: RADIUS, VIEW & REALTIME
-- ==========================================
-- 1. Sets Radius to 15km (PER USER REQUEST)
-- 2. Restores Order Detail features by selecting ALL columns
-- 3. Enables Real-time for Rider Locations

BEGIN;

-- [1] VENDOR RADIUS FIX (15KM STRICT)
CREATE OR REPLACE FUNCTION public.get_nearby_vendors_v2(
    customer_lat DOUBLE PRECISION,
    customer_lng DOUBLE PRECISION
)
RETURNS TABLE (
    id TEXT,
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
        v.id::TEXT, 
        v.name::TEXT,
        v.address::TEXT,
        v.latitude::DOUBLE PRECISION,
        v.longitude::DOUBLE PRECISION,
        COALESCE(v.delivery_radius_km, 0)::DOUBLE PRECISION,
        v.status::TEXT,
        (
            6371 * acos(
                LEAST(1.0, GREATEST(-1.0, 
                    cos(radians(customer_lat)) * cos(radians(v.latitude::DOUBLE PRECISION)) *
                    cos(radians(v.longitude::DOUBLE PRECISION) - radians(customer_lng)) +
                    sin(radians(customer_lat)) * sin(radians(v.latitude::DOUBLE PRECISION))
                ))
            )
        )::DOUBLE PRECISION AS distance_km,
        COALESCE(v.rating, 0)::DOUBLE PRECISION,
        v.cuisine_type::TEXT,
        v.image_url::TEXT,
        v.banner_url::TEXT,
        v.delivery_time::TEXT,
        COALESCE(v.is_pure_veg, FALSE)::BOOLEAN,
        COALESCE(v.has_offers, FALSE)::BOOLEAN,
        COALESCE(v.is_busy, FALSE)::BOOLEAN
    FROM public.vendors v
    WHERE 
        v.status IN ('ONLINE', 'OPEN', 'ACTIVE', 'BUSY')
        AND v.latitude IS NOT NULL 
        AND v.longitude IS NOT NULL
        AND (
            6371 * acos(
                LEAST(1.0, GREATEST(-1.0, 
                    cos(radians(customer_lat)) * cos(radians(v.latitude::DOUBLE PRECISION)) *
                    cos(radians(v.longitude::DOUBLE PRECISION) - radians(customer_lng)) +
                    sin(radians(customer_lat)) * sin(radians(v.latitude::DOUBLE PRECISION))
                ))
            )
        ) <= 15.0 -- 🎯 FIXED: 15KM RADIUS
    ORDER BY distance_km ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- [2] VIEW FIX: RESTORE ALL ORDER FEATURES
DROP VIEW IF EXISTS public.view_customer_orders CASCADE;
CREATE OR REPLACE VIEW public.view_customer_orders AS
SELECT 
    o.*, -- 🎯 RESTORES ALL OLD FEATURES (OTPs, bill_details, timestamps)
    v.name as vendor_name,
    v.address as vendor_address,
    v.latitude as vendor_lat,
    v.longitude as vendor_lng,
    v.image_url as vendor_logo,
    dr.name as rider_name,
    dr.phone as rider_phone,
    dr.vehicle_number as rider_vehicle,
    dr.current_lat as rider_lat,
    dr.current_lng as rider_lng
FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id::TEXT = v.id::TEXT
LEFT JOIN public.delivery_riders dr ON o.rider_id::TEXT = dr.id::TEXT;

-- [3] REALTIME TRACKING RE-ENABLE
-- Ensure tables are in publication
ALTER PUBLICATION supabase_realtime ADD TABLE public.rider_locations;
ALTER PUBLICATION supabase_realtime ADD TABLE public.delivery_riders;
ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;

-- [4] PERMISSIONS (Global)
GRANT EXECUTE ON FUNCTION public.get_nearby_vendors_v2 TO anon, authenticated, service_role;
GRANT SELECT ON public.view_customer_orders TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.rider_locations TO anon, authenticated, service_role;

NOTIFY pgrst, 'reload schema';
COMMIT;
