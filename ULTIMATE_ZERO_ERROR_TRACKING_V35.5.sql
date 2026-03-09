-- 🛰️ THE ULTIMATE "ZERO-ERROR" TRACKING SYSTEM (V35.5) - DUAL-APP SYNC REPAIR
-- 🎯 MISSION: Resolve UI status discrepancies and Radar/Scanning loop.

BEGIN;

-- 1. DROP broken views/functions to ensure clean re-application
DROP VIEW IF EXISTS public.order_details_v3 CASCADE;

-- 2. 🏆 THE "TRUTH" VIEW (Granular Status Mapping)
-- Fixes the "Order Placed" vs "Ready" discrepancy in the progress bar.
CREATE OR REPLACE VIEW public.order_details_v3 AS
SELECT 
    o.id,
    o.customer_id,
    o.vendor_id,
    o.rider_id,
    o.items,
    o.total,
    o.status,
    o.payment_method,
    o.payment_status,
    o.address as raw_address,
    o.delivery_address,
    o.delivery_lat,
    o.delivery_lng,
    o.pickup_lat,
    o.pickup_lng,
    o.pickup_otp,
    o.delivery_otp,
    o.created_at,
    o.delivered_at,
    o.eta_minutes,
    
    -- Calculated Address
    COALESCE(NULLIF(o.delivery_address, '{}'), o.address, 'My Address') as effective_address,
    
    -- Vendor Details (Flattened)
    v.name as vendor_name,
    v.address as vendor_address,
    v.phone as vendor_phone,
    v.image_url as vendor_image_url,
    COALESCE(o.pickup_lat, v.latitude) as resolved_pickup_lat,
    COALESCE(o.pickup_lng, v.longitude) as resolved_pickup_lng,
    
    -- Customer Details (Flattened)
    cp.full_name as customer_name,
    cp.phone as customer_phone,
    cp.avatar_url as customer_avatar,

    -- Rider Details (Flattened)
    dr.name as rider_name,
    dr.phone as rider_phone,
    dr.profile_image as rider_avatar,
    dr.rating as rider_rating,
    dr.vehicle_number as rider_vehicle,
    dr.current_lat as rider_live_lat,
    dr.current_lng as rider_live_lng,
    
    -- UI Display Logic (Unified Labeling)
    CASE 
        WHEN lower(o.status) = 'placed' THEN 'Order Placed'
        WHEN lower(o.status) IN ('accepted', 'rider_assigned') THEN 'Order Accepted'
        WHEN lower(o.status) = 'preparing' THEN 'Chef is Cooking'
        WHEN lower(o.status) IN ('ready', 'ready_for_pickup') THEN 'Ready for Pickup'
        WHEN lower(o.status) IN ('picked_up', 'picking_up') THEN 'Rider Picked Food'
        WHEN lower(o.status) = 'on_the_way' THEN 'Rider is On The Way'
        WHEN lower(o.status) = 'delivered' THEN 'Delivered'
        ELSE UPPER(REPLACE(o.status, '_', ' '))
    END as status_display,

    -- 7-Step Progress Logic (Maps 1-to-1 with the App Stepper)
    CASE 
        WHEN lower(o.status) = 'placed' THEN 1
        WHEN lower(o.status) IN ('accepted', 'rider_assigned') THEN 2
        WHEN lower(o.status) = 'preparing' THEN 3
        WHEN lower(o.status) IN ('ready', 'ready_for_pickup') THEN 4
        WHEN lower(o.status) IN ('picked_up', 'picking_up') THEN 5
        WHEN lower(o.status) = 'on_the_way' THEN 6
        WHEN lower(o.status) = 'delivered' THEN 7
        ELSE 1
    END as current_step

FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id::TEXT = v.id::TEXT
LEFT JOIN public.delivery_riders dr ON o.rider_id::TEXT = dr.id::TEXT
LEFT JOIN public.customer_profiles cp ON o.customer_id::TEXT = cp.id::TEXT;

GRANT SELECT ON public.order_details_v3 TO anon, authenticated, service_role;

COMMIT;
