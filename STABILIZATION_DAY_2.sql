-- 🚀 DAY 2: CLEAN ORDER STRUCTURE (SINGLE SOURCE OF TRUTH)
-- Goal: Standardize the orders table to include all required tracking and status fields.

BEGIN;

-- 1. Ensure all required columns exist in the physical 'orders' table
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS customer_id_new TEXT; 
-- (Assuming customer_id might be UUID in some old versions, we ensure it's TEXT for Firebase UID)

-- Add missing tracking columns
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_lat DOUBLE PRECISION;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_lng DOUBLE PRECISION;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS vendor_lat DOUBLE PRECISION;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS vendor_lng DOUBLE PRECISION;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS rider_lat DOUBLE PRECISION;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS rider_lng DOUBLE PRECISION;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMPTZ;

-- Add standardized status columns if missing
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS order_status TEXT DEFAULT 'PLACED';
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS payment_status TEXT DEFAULT 'PENDING';
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS total_amount DOUBLE PRECISION DEFAULT 0.0;

-- 2. Data Migration (Copy from old names if they exist)
UPDATE public.orders SET order_status = status WHERE order_status IS NULL AND status IS NOT NULL;
UPDATE public.orders SET total_amount = total WHERE total_amount = 0 AND total IS NOT NULL;
UPDATE public.orders SET vendor_lat = pickup_lat WHERE vendor_lat IS NULL AND pickup_lat IS NOT NULL;
UPDATE public.orders SET vendor_lng = pickup_lng WHERE vendor_lng IS NULL AND pickup_lng IS NOT NULL;

-- 3. Create Backend-Driven Status RPCs
-- This prevents frontend from directly modifying status via .update()

-- ACCEPT ORDER (Vendor)
CREATE OR REPLACE FUNCTION public.vendor_accept_order_v2(p_order_id TEXT)
RETURNS VOID AS $$
BEGIN
    UPDATE public.orders SET 
        order_status = 'ACCEPTED',
        updated_at = now()
    WHERE (id::text) = (p_order_id::text);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ASSIGN RIDER (Backend/Admin)
CREATE OR REPLACE FUNCTION public.assign_rider_v2(p_order_id TEXT, p_rider_id TEXT)
RETURNS VOID AS $$
BEGIN
    UPDATE public.orders SET 
        rider_id = p_rider_id,
        order_status = 'RIDER_ASSIGNED',
        updated_at = now()
    WHERE (id::text) = (p_order_id::text);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- PICKUP ORDER (Rider)
CREATE OR REPLACE FUNCTION public.rider_pickup_order_v2(p_order_id TEXT)
RETURNS VOID AS $$
BEGIN
    UPDATE public.orders SET 
        order_status = 'PICKED_UP',
        updated_at = now()
    WHERE (id::text) = (p_order_id::text);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- DELIVER ORDER (Rider)
CREATE OR REPLACE FUNCTION public.rider_deliver_order_v2(p_order_id TEXT)
RETURNS VOID AS $$
BEGIN
    UPDATE public.orders SET 
        order_status = 'DELIVERED',
        delivered_at = now(),
        updated_at = now()
    WHERE (id::text) = (p_order_id::text);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Update the Stabilized View to use these physical columns
DROP VIEW IF EXISTS public.order_tracking_stabilized_v1;
CREATE OR REPLACE VIEW public.order_tracking_stabilized_v1 AS
SELECT 
    o.id AS order_id, 
    o.id AS id, 
    o.customer_id, 
    o.vendor_id, 
    o.rider_id AS delivery_id,
    o.order_status, 
    o.order_status AS status,
    o.payment_status, 
    o.payment_status AS payment_state,
    o.total_amount,
    o.total_amount AS total,
    o.delivery_address,
    o.delivery_lat, 
    o.delivery_lng, 
    o.vendor_lat, 
    o.vendor_lng,
    o.rider_lat, 
    o.rider_lng, 
    o.delivered_at,
    o.created_at, 
    v.name AS vendor_name, 
    v.image_url AS vendor_image,
    r.name AS rider_name, 
    r.phone AS rider_phone
FROM public.orders o
LEFT JOIN public.vendors v ON (o.vendor_id::text) = (v.id::text)
LEFT JOIN public.delivery_riders r ON (o.rider_id::text) = (r.id::text);

COMMIT;
