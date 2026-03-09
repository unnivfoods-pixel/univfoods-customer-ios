-- 🚨 REPAIR LOGISTICS STATUS MAPPING (v77)
-- Fixes 'Preparing' and 'Ready' statuses in the customer tracking view.

BEGIN;

DROP VIEW IF EXISTS public.order_tracking_stabilized_v1 CASCADE;

CREATE OR REPLACE VIEW public.order_tracking_stabilized_v1 AS
SELECT 
    o.id::TEXT AS order_id,
    o.id::TEXT AS id,
    o.customer_id::TEXT,
    o.vendor_id::TEXT,
    o.rider_id::TEXT,
    COALESCE(o.order_status, o.status, 'PLACED')::TEXT as order_status,
    o.payment_status::TEXT,
    o.payment_method::TEXT,
    COALESCE(o.total_amount, o.total)::NUMERIC as total_amount,
    COALESCE(o.delivery_address, 'Address not found')::TEXT as delivery_address,
    o.delivery_lat::DOUBLE PRECISION,
    o.delivery_lng::DOUBLE PRECISION,
    o.vendor_lat::DOUBLE PRECISION,
    o.vendor_lng::DOUBLE PRECISION,
    o.rider_lat::DOUBLE PRECISION,
    o.rider_lng::DOUBLE PRECISION,
    o.items,
    o.created_at,
    o.updated_at,
    CASE 
        WHEN COALESCE(o.order_status, o.status) = 'PAYMENT_PENDING' THEN 'Payment Pending'
        WHEN COALESCE(o.order_status, o.status) = 'PLACED' THEN 'Order Placed'
        WHEN COALESCE(o.order_status, o.status) = 'ACCEPTED' THEN 'Accepted'
        WHEN COALESCE(o.order_status, o.status) = 'PREPARING' THEN 'Preparing'
        WHEN COALESCE(o.order_status, o.status) = 'COOKING' THEN 'Cooking'
        WHEN COALESCE(o.order_status, o.status) = 'READY' THEN 'Ready'
        WHEN COALESCE(o.order_status, o.status) = 'PICKED_UP' THEN 'Out for Delivery'
        WHEN COALESCE(o.order_status, o.status) = 'DELIVERED' THEN 'Delivered'
        WHEN COALESCE(o.order_status, o.status) = 'CANCELLED' THEN 'Cancelled'
        ELSE COALESCE(o.order_status, o.status)
    END AS status_display,
    CASE 
        WHEN COALESCE(o.order_status, o.status) = 'PLACED' THEN 1
        WHEN COALESCE(o.order_status, o.status) = 'ACCEPTED' THEN 2
        WHEN COALESCE(o.order_status, o.status) = 'PREPARING' THEN 3
        WHEN COALESCE(o.order_status, o.status) = 'COOKING' THEN 4
        WHEN COALESCE(o.order_status, o.status) = 'READY' THEN 5
        WHEN COALESCE(o.order_status, o.status) = 'PICKED_UP' THEN 6
        WHEN COALESCE(o.order_status, o.status) = 'DELIVERED' THEN 7
        ELSE 1
    END AS current_step,
    v.name::TEXT AS vendor_name,
    COALESCE(v.image_url, v.banner_url)::TEXT AS vendor_image,
    v.logo_url::TEXT AS vendor_logo,
    v.phone::TEXT AS vendor_phone,
    v.address::TEXT AS vendor_address,
    COALESCE(r.name::TEXT, 'Rider Assigned')::TEXT AS rider_name,
    r.phone::TEXT AS rider_phone,
    r.profile_image::TEXT AS rider_avatar,
    r.rating::TEXT AS rider_rating,
    r.vehicle_number::TEXT AS rider_vehicle
FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id::TEXT = v.id::TEXT
LEFT JOIN public.delivery_riders r ON o.rider_id::TEXT = r.id::TEXT;

COMMIT;
