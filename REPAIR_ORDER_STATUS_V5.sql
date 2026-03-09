-- 🛰️ COMPLETE REPAIR V5: STATUS SYNC + ALIASED TOTAL + RIDER NAME + 15KM DISTANCE
-- This script fixes the issue where cancelled orders show as 'PLACED' by mapping 'order_status' to 'status'.

BEGIN;

-- 🛡️ 1. DROP EXISTING VIEW
DROP VIEW IF EXISTS public.order_tracking_stabilized_v1;

-- 🛡️ 2. CREATE STABILIZED VIEW WITH COMPATIBILITY ALIASES
CREATE OR REPLACE VIEW public.order_tracking_stabilized_v1 AS
SELECT 
    o.id AS order_id, 
    o.id AS id, 
    o.customer_id, 
    o.vendor_id, 
    o.rider_id,
    o.order_status, 
    o.order_status AS status,      -- 🛡️ CRITICAL: Map to app's 'status' field
    o.payment_status, 
    o.payment_status AS payment_state, -- 🛡️ CRITICAL: Map to app's 'payment_state' field
    o.payment_method, 
    o.total_amount,
    o.total_amount AS total,       -- 🛡️ COMPATIBILITY ALIAS FOR ₹0 PRICE FIX
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
        WHEN o.order_status = 'READY' THEN 'Ready for Pickup'
        WHEN o.order_status = 'PICKED_UP' THEN 'Out for Delivery'
        WHEN o.order_status = 'DELIVERED' THEN 'Delivered'
        WHEN o.order_status = 'CANCELLED' THEN 'Cancelled'
        WHEN o.order_status = 'REJECTED' THEN 'Rejected'
        ELSE o.order_status 
    END AS status_display,
    v.name AS vendor_name, 
    v.image_url AS vendor_image,
    v.image_url AS vendor_logo_url, -- 🛡️ COMPATIBILITY ALIAS FOR APP
    r.name AS rider_name, 
    r.phone AS rider_phone, 
    r.avatar_url AS rider_avatar,
    r.rating AS rider_rating, 
    r.vehicle_number AS rider_vehicle
FROM public.orders o
LEFT JOIN public.vendors v ON (o.vendor_id::text) = (v.id::text)
LEFT JOIN public.delivery_riders r ON (o.rider_id::text) = (r.id::text);

-- 🛡️ 3. RE-SYNC REALTIME (Optional but ensures schema reload)
NOTIFY pgrst, 'reload schema';

COMMIT;

SELECT 'DATABASE STABILIZED V5: STATUS DISCREPANCY REPAIRED' as status;
