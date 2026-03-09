-- 🛰️ COMPLETE REPAIR V4: ALIASED TOTAL + RIDER NAME + 15KM DISTANCE + OPEN/CLOSE TIMES
-- This script fixes the zero price issue by adding a 'total' alias to 'total_amount'.

BEGIN;

-- 🛡️ 1. DROP EXISTING VIEW
DROP VIEW IF EXISTS public.order_tracking_stabilized_v1;

-- 🛡️ 2. CREATE STABILIZED VIEW
CREATE OR REPLACE VIEW public.order_tracking_stabilized_v1 AS
SELECT 
    o.id AS order_id, 
    o.id AS id, 
    o.customer_id, 
    o.vendor_id, 
    o.rider_id,
    o.order_status, 
    o.payment_status, 
    o.payment_method, 
    o.total_amount,
    o.total_amount AS total, -- 🛡️ COMPATIBILITY ALIAS FOR ₹0 PRICE FIX
    COALESCE(o.delivery_address, 'Address not found') as delivery_address,
    o.delivery_lat, 
    o.delivery_lng, 
    o.vendor_lat, 
    o.vendor_lng,
    o.rider_lat, 
    o.rider_lng, 
    o.items, 
    o.created_at, 
    o.updated_at,
    CASE 
        WHEN o.order_status = 'PLACED' THEN 'Order Placed'
        WHEN o.order_status = 'ACCEPTED' THEN 'Preparing'
        WHEN o.order_status = 'PICKED_UP' THEN 'Out for Delivery'
        WHEN o.order_status = 'DELIVERED' THEN 'Delivered'
        ELSE o.order_status 
    END AS status_display,
    v.name AS vendor_name, 
    v.image_url AS vendor_image,
    r.name AS rider_name, 
    r.phone AS rider_phone, 
    r.avatar_url AS rider_avatar,
    r.rating AS rider_rating, 
    r.vehicle_number AS rider_vehicle
FROM public.orders o
LEFT JOIN public.vendors v ON (o.vendor_id::text) = (v.id::text)
LEFT JOIN public.delivery_riders r ON (o.rider_id::text) = (r.id::text);

-- 🛡️ 3. VENDOR RADIUS (15KM LIMIT) + OPEN/CLOSE TIMES
CREATE OR REPLACE FUNCTION public.get_nearby_vendors_v7(p_params JSONB)
RETURNS JSONB AS $$
DECLARE v_lat DOUBLE PRECISION; v_lng DOUBLE PRECISION; result JSONB;
BEGIN
    v_lat := (p_params->>'lat')::DOUBLE PRECISION;
    v_lng := (p_params->>'lng')::DOUBLE PRECISION;

    SELECT jsonb_agg(sub) INTO result FROM (
        SELECT 
            v.id, v.name, v.latitude as lat, v.longitude as lng, 
            (6371 * acos(LEAST(1.0, GREATEST(-1.0, cos(radians(v_lat)) * cos(radians(v.latitude)) * cos(radians(v.longitude) - radians(v_lng)) + sin(radians(v_lat)) * sin(radians(v.latitude))))))::DOUBLE PRECISION as distance_km,
            COALESCE(v.rating, 4.5)::DOUBLE PRECISION as rating, 
            COALESCE(v.cuisine_type, 'Indian')::TEXT as cuisine_type, 
            COALESCE(v.price_for_two::TEXT, '200') as price_for_two, 
            '25 min'::TEXT as delivery_time, 
            COALESCE(v.banner_url, v.image_url, 'https://images.unsplash.com/photo-1512132411229-c30391241dd8')::TEXT as banner_url,
            COALESCE(v.is_pure_veg, false) as is_pure_veg,
            true as has_offers, v.is_open,
            v.open_time, v.close_time, v.status
        FROM public.vendors v
        WHERE v.is_active = TRUE AND v.is_approved = TRUE
        AND (6371 * acos(LEAST(1.0, GREATEST(-1.0, cos(radians(v_lat)) * cos(radians(v.latitude)) * cos(radians(v.longitude) - radians(v_lng)) + sin(radians(v_lat)) * sin(radians(v.latitude)))))) <= 15.0
        ORDER BY distance_km ASC
    ) sub;
    RETURN COALESCE(result, '[]'::JSONB);
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- 🛡️ 4. ADMIN HELPER
CREATE OR REPLACE FUNCTION public.calculate_distance_km(lat1 DOUBLE PRECISION, lng1 DOUBLE PRECISION, lat2 DOUBLE PRECISION, lng2 DOUBLE PRECISION)
RETURNS DOUBLE PRECISION AS $$
BEGIN
    RETURN (6371 * acos(LEAST(1.0, GREATEST(-1.0, cos(radians(lat1)) * cos(radians(lat2)) * cos(radians(lng2) - radians(lng1)) + sin(radians(lat1)) * sin(radians(lat2))))));
END; $$ LANGUAGE plpgsql IMMUTABLE;

COMMIT;
SELECT 'DATABASE STABILIZED V4: TOTAL PRICE REPAIRED' as status;
