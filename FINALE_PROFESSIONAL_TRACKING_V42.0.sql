-- 🛰️ FINALE PROFESSIONAL TRACKING SYSTEM (V42.0)
-- 🎯 MISSION: Heart of the Delivery App. Real-time, Reliable, Robust.

BEGIN;

-- 1. 🏗️ INFRASTRUCTURE UPGRADE
-- Ensure the riders table has professional attributes
ALTER TABLE public.delivery_riders 
ADD COLUMN IF NOT EXISTS rating NUMERIC DEFAULT 4.8,
ADD COLUMN IF NOT EXISTS total_orders INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS profile_image TEXT,
ADD COLUMN IF NOT EXISTS vehicle_number TEXT,
ADD COLUMN IF NOT EXISTS phone TEXT,
ADD COLUMN IF NOT EXISTS current_lat DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS current_lng DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS last_gps_update TIMESTAMPTZ;

-- Ensure logical timestamps in orders
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS assigned_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS pickup_time TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS pickup_otp TEXT,
ADD COLUMN IF NOT EXISTS delivery_otp TEXT,
ADD COLUMN IF NOT EXISTS eta_display TEXT DEFAULT 'Calculating...';

-- 2. 💬 REAL-TIME CHAT & MESSAGES
CREATE TABLE IF NOT EXISTS public.order_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES public.orders(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL,
    sender_role TEXT NOT NULL, -- 'customer', 'rider', 'vendor'
    message TEXT NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 3. 📍 HIGH-FREQUENCY LIVE TRACKING (5 SEC PULSE)
CREATE TABLE IF NOT EXISTS public.order_live_tracking (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES public.orders(id) ON DELETE CASCADE,
    rider_id UUID REFERENCES public.delivery_riders(id) ON DELETE CASCADE,
    rider_lat DOUBLE PRECISION NOT NULL,
    rider_lng DOUBLE PRECISION NOT NULL,
    speed DOUBLE PRECISION DEFAULT 0,
    heading DOUBLE PRECISION DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Set Replica Identity to FULL for Realtime to work across all apps
ALTER TABLE public.orders REPLICA IDENTITY FULL;
ALTER TABLE public.order_live_tracking REPLICA IDENTITY FULL;
ALTER TABLE public.order_messages REPLICA IDENTITY FULL;
ALTER TABLE public.delivery_riders REPLICA IDENTITY FULL;

-- 4. 🔗 THE TRUTH VIEW (Unified logic for all 3 apps)
DROP VIEW IF EXISTS public.order_details_v3 CASCADE;
CREATE OR REPLACE VIEW public.order_details_v3 AS
SELECT 
    o.id as order_id,
    o.*,
    
    -- Vendor Details
    v.name as vendor_name,
    v.address as vendor_address,
    v.phone as vendor_phone,
    v.image_url as vendor_image_url,
    v.latitude as vendor_lat,
    v.longitude as vendor_lng,
    v.owner_id as vendor_owner_id,
    
    -- Customer Details
    cp.full_name as customer_name,
    cp.phone as customer_phone,
    cp.avatar_url as customer_avatar,
    
    -- Rider Details
    dr.name as rider_name,
    dr.phone as rider_phone,
    dr.vehicle_number as rider_vehicle,
    dr.profile_image as rider_avatar,
    dr.rating as rider_rating,
    dr.total_orders as rider_total_orders,
    
    -- Display Mapping
    CASE 
        WHEN o.status = 'placed' THEN 'Order Placed'
        WHEN o.status = 'accepted' THEN 'Rider Assigned' -- Changed per request for immediate visibility
        WHEN o.status = 'preparing' THEN 'Chef is Cooking'
        WHEN o.status = 'ready' THEN 'Ready for Pickup'
        WHEN o.status = 'picked_up' THEN 'Food Picked Up'
        WHEN o.status = 'on_the_way' THEN 'Out for Delivery'
        WHEN o.status = 'delivered' THEN 'Delivered'
        ELSE UPPER(o.status)
    END as status_display,

    -- Step Mapping (1-5)
    CASE 
        WHEN o.status IN ('placed', 'accepted', 'RIDER_ASSIGNED') THEN 1
        WHEN o.status IN ('preparing', 'ready') THEN 2
        WHEN o.status = 'picked_up' THEN 3
        WHEN o.status = 'on_the_way' THEN 4
        WHEN o.status = 'delivered' THEN 5
        ELSE 1
    END as current_step

FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id::UUID = v.id
LEFT JOIN public.customer_profiles cp ON o.customer_id::UUID = cp.id
LEFT JOIN public.delivery_riders dr ON o.rider_id::UUID = dr.id;

-- 5. ⚡ LOGISTICS ENGINE (RPC Functions)

-- Accept Order (Immediate UI update)
CREATE OR REPLACE FUNCTION public.accept_order_v1(p_order_id UUID, p_rider_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE public.orders 
    SET status = 'accepted',
        rider_id = p_rider_id,
        assigned_at = now()
    WHERE id = p_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Pickup Food (Tracking starts)
CREATE OR REPLACE FUNCTION public.pickup_order_v1(p_order_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE public.orders 
    SET status = 'picked_up',
        pickup_time = now()
    WHERE id = p_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- High Frequency Tracking Pulse
CREATE OR REPLACE FUNCTION public.update_order_tracking_v1(
    p_order_id UUID, 
    p_rider_id UUID, 
    p_lat DOUBLE PRECISION, 
    p_lng DOUBLE PRECISION,
    p_speed DOUBLE PRECISION,
    p_heading DOUBLE PRECISION
)
RETURNS VOID AS $$
BEGIN
    -- 1. Insert snapshot for history / UI pulse
    INSERT INTO public.order_live_tracking (order_id, rider_id, rider_lat, rider_lng, speed, heading)
    VALUES (p_order_id, p_rider_id, p_lat, p_lng, p_speed, p_heading);
    
    -- 2. Update current rider location
    UPDATE public.delivery_riders 
    SET current_lat = p_lat,
        current_lng = p_lng,
        last_gps_update = now()
    WHERE id = p_rider_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. 🔓 REAL-TIME PUBLICATION
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR TABLE 
    public.orders, 
    public.order_live_tracking, 
    public.order_messages, 
    public.delivery_riders,
    public.vendors;

COMMIT;
NOTIFY pgrst, 'reload schema';
