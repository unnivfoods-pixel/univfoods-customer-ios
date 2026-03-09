-- LOGISTICS DATA REPAIR & REINFORCEMENT (v1.0)
-- RUN THIS TO FIX BLANK NAMES IN ADMIN PANEL

BEGIN;

-- 1. DROP THE OLD VIEW COMPLETELY
DROP VIEW IF EXISTS public.order_details_v3 CASCADE;

-- 2. ENSURE ALL SNAPSHOT COLUMNS EXIST IN ORDERS
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS customer_name TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS customer_phone TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS vendor_name TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS vendor_address TEXT;

-- 3. REPAIR DATA: Fill in blanks for existing orders
UPDATE public.orders SET 
    customer_name = 'Guest' WHERE customer_name IS NULL OR TRIM(customer_name) = '';
UPDATE public.orders SET 
    customer_phone = 'No Phone' WHERE customer_phone IS NULL OR TRIM(customer_phone) = '';
UPDATE public.orders SET 
    vendor_name = 'Generic Station' WHERE vendor_name IS NULL OR TRIM(vendor_name) = '';

-- 4. REBUILD THE VIEW WITH EXTREME FALLBACKS (Use TRIM to catch empty strings)
CREATE VIEW public.order_details_v3 AS
SELECT 
    o.id as order_id,
    o.customer_id,
    o.vendor_id,
    o.rider_id,
    o.items,
    o.total,
    o.status,
    o.payment_method,
    o.payment_status,
    o.delivery_address,
    o.delivery_lat,
    o.delivery_lng,
    o.vendor_lat,
    o.vendor_lng,
    o.rider_lat,
    o.rider_lng,
    o.rider_last_seen,
    o.estimated_arrival_time,
    o.cooking_instructions,
    o.created_at,
    o.assigned_at,
    o.pickup_time,
    o.delivered_at,
    o.cancelled_at,
    -- Enhanced name extraction with triple-layer fallback
    COALESCE(
        NULLIF(TRIM(v.name), ''), 
        NULLIF(TRIM(o.vendor_name), ''), 
        'Station: Unknown'
    ) as vendor_name,
    COALESCE(
        NULLIF(TRIM(v.address), ''), 
        NULLIF(TRIM(o.vendor_address), ''), 
        'Address Unrecorded'
    ) as vendor_address,
    v.phone as vendor_phone,
    v.image_url as vendor_image_url,
    v.owner_id as vendor_owner_id,
    -- Extreme Customer fallback (Name + Phone)
    COALESCE(
        NULLIF(TRIM(cp.full_name), ''), 
        NULLIF(TRIM(o.customer_name), ''), 
        'Client: Guest'
    ) as customer_name,
    COALESCE(
        NULLIF(TRIM(cp.phone), ''), 
        NULLIF(TRIM(o.customer_phone), ''), 
        'No Phone'
    ) as customer_phone,
    cp.avatar_url as customer_avatar,
    dr.name as rider_name,
    dr.phone as rider_phone,
    dr.vehicle_number as rider_vehicle,
    dr.profile_image as rider_avatar,
    dr.rating as rider_rating,
    dr.total_orders as rider_total_orders,
    -- Label logic for UI
    CASE 
        WHEN o.status = 'placed' THEN 'Order Placed'
        WHEN o.status = 'accepted' THEN 'Rider Assigned'
        WHEN o.status = 'preparing' THEN 'Chef is Cooking'
        WHEN o.status = 'ready' THEN 'Ready for Pickup'
        WHEN o.status = 'picked_up' THEN 'Food Picked Up'
        WHEN o.status = 'on_the_way' THEN 'Out for Delivery'
        WHEN o.status = 'delivered' THEN 'Delivered'
        ELSE UPPER(o.status)
    END as status_display
FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id = v.id
LEFT JOIN public.customer_profiles cp ON o.customer_id = cp.id
LEFT JOIN public.delivery_riders dr ON o.rider_id = dr.id;

-- 5. BROADCAST DATA REFRESH
ALTER TABLE public.orders REPLICA IDENTITY FULL;

COMMIT;
SELECT 'LOGISTICS GRID REPAIRED SUCCESSFULLY' as status;
