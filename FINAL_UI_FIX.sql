-- FINAL UI & TRACKING FIX (REPAIRED v2)
-- 1. Fix the stabilized view to properly map vendor coordinates and correct vendor/rider tables
DROP VIEW IF EXISTS public.order_tracking_stabilized_v1 CASCADE;

CREATE VIEW public.order_tracking_stabilized_v1 AS
SELECT 
    o.id as order_id,
    o.id,
    o.customer_id,
    o.vendor_id,
    o.rider_id,
    COALESCE(o.order_status, o.status, 'PLACED') as order_status,
    o.payment_status,
    o.payment_method,
    COALESCE(o.total_amount, o.total, 0) as total_amount,
    o.delivery_address,
    o.delivery_lat,
    o.delivery_lng,
    COALESCE(o.vendor_lat, v.latitude, v.lat) as vendor_lat,
    COALESCE(o.vendor_lng, v.longitude, v.lng) as vendor_lng,
    lt.rider_lat,
    lt.rider_lng,
    o.items,
    o.created_at,
    o.updated_at,
    CASE 
        WHEN COALESCE(o.order_status, o.status) = 'PLACED' THEN 'Order Placed'
        WHEN COALESCE(o.order_status, o.status) = 'ACCEPTED' THEN 'Preparing'
        WHEN COALESCE(o.order_status, o.status) = 'READY' THEN 'Ready'
        WHEN COALESCE(o.order_status, o.status) = 'PICKED_UP' THEN 'On the way'
        WHEN COALESCE(o.order_status, o.status) = 'DELIVERED' THEN 'Delivered'
        ELSE COALESCE(o.order_status, o.status)
    END as status_display,
    CASE 
        WHEN COALESCE(o.order_status, o.status) = 'PLACED' THEN 1
        WHEN COALESCE(o.order_status, o.status) = 'ACCEPTED' THEN 2
        WHEN COALESCE(o.order_status, o.status) = 'READY' THEN 3
        WHEN COALESCE(o.order_status, o.status) = 'PICKED_UP' THEN 4
        WHEN COALESCE(o.order_status, o.status) = 'DELIVERED' THEN 5
        ELSE 1
    END as current_step,
    COALESCE(v.shop_name, v.name, 'UNIV Station') as vendor_name,
    v.image_url as vendor_image,
    v.logo_url as vendor_logo,
    v.phone as vendor_phone,
    v.address as vendor_address,
    rp.name as rider_name,
    rp.phone as rider_phone,
    COALESCE(rp.avatar_url, rp.profile_image) as rider_avatar,
    rp.rating as rider_rating,
    rp.vehicle_type as rider_vehicle
FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id = v.id
LEFT JOIN public.delivery_riders rp ON o.rider_id = rp.id
LEFT JOIN (
    SELECT DISTINCT ON (order_id) order_id, rider_lat, rider_lng
    FROM public.order_live_tracking
    ORDER BY order_id, created_at DESC
) lt ON o.id = lt.order_id;

-- 2. Ensure Realtime is active for base tables
ALTER TABLE public.orders REPLICA IDENTITY FULL;
-- Check if order_live_tracking exists before altering
DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'order_live_tracking') THEN
        ALTER TABLE public.order_live_tracking REPLICA IDENTITY FULL;
    END IF;
END $$;

-- 3. Cleanup: Ensure the profile for the master ID has the phone number if missing
UPDATE public.customer_profiles cp
SET phone = o.customer_phone
FROM public.orders o
WHERE cp.id = o.customer_id
AND (cp.phone IS NULL OR cp.phone = '')
AND o.customer_phone IS NOT NULL;
