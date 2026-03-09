-- FIX TRACKING VIEW v101.2
-- 🎯 MISSION: Include delivery_address in the tracking view and fix coordinate precision.

BEGIN;

-- Update the view to include delivery_address and pincode if available
CREATE OR REPLACE VIEW order_tracking_stabilized_v1 AS
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
    COALESCE(o.delivery_address, 'Address not found') as delivery_address, -- 🛡️ CRITICAL FIX
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
        WHEN o.order_status = 'PAYMENT_PENDING' THEN 'Payment Pending'
        WHEN o.order_status = 'PLACED' THEN 'Order Placed'
        WHEN o.order_status = 'ACCEPTED' THEN 'Preparing'
        WHEN o.order_status = 'COOKING' THEN 'Cooking'
        WHEN o.order_status = 'PICKED_UP' THEN 'Out for Delivery'
        WHEN o.order_status = 'DELIVERED' THEN 'Delivered'
        WHEN o.order_status = 'CANCELLED' THEN 'Cancelled'
        ELSE o.order_status 
    END AS status_display,
    CASE 
        WHEN o.order_status = 'PLACED' THEN 1
        WHEN o.order_status = 'ACCEPTED' THEN 2
        WHEN o.order_status = 'COOKING' THEN 3
        WHEN o.order_status = 'PICKED_UP' THEN 4
        WHEN o.order_status = 'DELIVERED' THEN 5
        ELSE 1
    END AS current_step,
    v.name AS vendor_name,
    v.image_url AS vendor_image,
    v.logo_url AS vendor_logo,
    v.phone AS vendor_phone,
    v.address AS vendor_address,
    r.full_name AS rider_name,
    r.phone AS rider_phone,
    r.avatar_url AS rider_avatar,
    r.rating AS rider_rating,
    r.vehicle_details AS rider_vehicle
FROM orders o
LEFT JOIN vendors v ON (o.vendor_id::text) = (v.id::text)
LEFT JOIN delivery_riders r ON (o.rider_id::text) = (r.id::text);

COMMIT;
SELECT 'TRACKING VIEW V101.2 UPDATED WITH DELIVERY ADDRESS' as status;
