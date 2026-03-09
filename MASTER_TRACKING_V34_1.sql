-- 🛰️ THE TRACKING TRUTH PROTOCOL (V34.1)
-- 🎯 UNIFICATION: Solving the "Static Marker" and "Missing Data" issues.

BEGIN;

-- 1. Ensure Columns exist in orders for Lifecycle Analytics
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS accepted_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS assigned_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS pickup_time TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS delivery_duration_seconds INTEGER,
ADD COLUMN IF NOT EXISTS preparation_duration_seconds INTEGER;

-- 2. Ensure Rider Fields for Premium UI
ALTER TABLE public.delivery_riders
ADD COLUMN IF NOT EXISTS current_lat DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS current_lng DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS heading DOUBLE PRECISION DEFAULT 0,
ADD COLUMN IF NOT EXISTS speed DOUBLE PRECISION DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_gps_update TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS rating NUMERIC DEFAULT 4.8,
ADD COLUMN IF NOT EXISTS vehicle_number TEXT,
ADD COLUMN IF NOT EXISTS profile_image TEXT;

-- 3. Create high-frequency tracking table for history/audit
CREATE TABLE IF NOT EXISTS public.order_live_tracking (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES public.orders(id) ON DELETE CASCADE,
    rider_id UUID REFERENCES public.delivery_riders(id),
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    speed DOUBLE PRECISION,
    heading DOUBLE PRECISION,
    created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.order_live_tracking REPLICA IDENTITY FULL;

-- 4. THE MASTER SYNC RPC (Called by Rider App every 5 seconds)
CREATE OR REPLACE FUNCTION public.update_delivery_location_v16(
    p_order_id UUID,
    p_rider_id TEXT,
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION,
    p_speed DOUBLE PRECISION DEFAULT 0,
    p_heading DOUBLE PRECISION DEFAULT 0
)
RETURNS VOID AS $$
BEGIN
    -- 1. Update Rider Table (For Global Radar & Realtime Subscription)
    UPDATE public.delivery_riders SET
        current_lat = p_lat,
        current_lng = p_lng,
        speed = p_speed,
        heading = p_heading,
        last_gps_update = now()
    WHERE id::TEXT = p_rider_id;

    -- 2. Insert into History (For path reconstruction / audit)
    INSERT INTO public.order_live_tracking (order_id, rider_id, latitude, longitude, speed, heading)
    VALUES (p_order_id, p_rider_id::UUID, p_lat, p_lng, p_speed, p_heading);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. UPGRADE ORDER VIEW (Human Translation Layer)
DROP VIEW IF EXISTS public.order_details_v3 CASCADE;
CREATE OR REPLACE VIEW public.order_details_v3 AS
SELECT 
    o.*,
    COALESCE(NULLIF(o.delivery_address, '{}'), o.address, 'My Address') as effective_address,
    v.name as vendor_name,
    v.address as vendor_address,
    v.phone as vendor_phone,
    v.image_url as vendor_image_url,
    dr.name as rider_name,
    dr.phone as rider_phone,
    dr.profile_image as rider_avatar,
    dr.rating as rider_rating,
    dr.vehicle_number as rider_vehicle,
    dr.current_lat as rider_live_lat,
    dr.current_lng as rider_live_lng,
    CASE 
        WHEN o.status = 'placed' THEN 'Order Placed'
        WHEN o.status = 'accepted' THEN 'Order Accepted'
        WHEN o.status = 'preparing' THEN 'Chef is Cooking'
        WHEN o.status = 'ready' THEN 'Ready for Pickup'
        WHEN o.status = 'picked_up' THEN 'Rider Picked Food'
        WHEN o.status = 'on_the_way' THEN 'Rider is On The Way'
        WHEN o.status = 'delivered' THEN 'Delivered'
        ELSE UPPER(o.status)
    END as status_display,
    CASE 
        WHEN o.status IN ('placed', 'accepted') THEN 1
        WHEN o.status = 'preparing' THEN 2
        WHEN o.status IN ('ready', 'picked_up') THEN 3
        WHEN o.status = 'on_the_way' THEN 4
        WHEN o.status = 'delivered' THEN 5
        ELSE 1
    END as current_step
FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id = v.id
LEFT JOIN public.delivery_riders dr ON o.rider_id = dr.id;

GRANT SELECT ON public.order_details_v3 TO anon, authenticated, service_role;

COMMIT;
