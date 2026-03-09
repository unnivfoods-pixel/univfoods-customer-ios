-- 🛰️ THE ULTIMATE "ZERO-ERROR" TRACKING SYSTEM (V35.1)
-- 🎯 MISSION: Full Professional Tracking, Realtime GPS, and Zero SQL Errors.
-- 🛠️ FIXES: "Duplicate Columns", "UUID vs TEXT Mismatch", and "Missing Tables".
-- USE THIS SCRIPT ONLY. It replaces all previous V33 and V34 scripts.

BEGIN;

-- ==========================================================
-- 🏗️ 1. INFRASTRUCTURE (Tables)
-- ==========================================================

-- A. Order Lifecycle Timestamps
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS delivery_address TEXT,
ADD COLUMN IF NOT EXISTS rider_id UUID,
ADD COLUMN IF NOT EXISTS accepted_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS assigned_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS pickup_time TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS eta_minutes INTEGER;

-- B. Rider Professional Profile
ALTER TABLE public.delivery_riders 
ADD COLUMN IF NOT EXISTS rating NUMERIC DEFAULT 4.8,
ADD COLUMN IF NOT EXISTS profile_image TEXT,
ADD COLUMN IF NOT EXISTS vehicle_number TEXT,
ADD COLUMN IF NOT EXISTS current_lat DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS current_lng DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS heading DOUBLE PRECISION DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_gps_update TIMESTAMPTZ;

-- C. High-Frequency Tracking Log
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

-- D. Order-Specific Chat
CREATE TABLE IF NOT EXISTS public.chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES public.orders(id) ON DELETE CASCADE,
    sender_id UUID,
    sender_role TEXT, -- 'CUSTOMER', 'RIDER'
    message TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ==========================================================
-- 🛡️ 2. CLEAN SLATE (Drop broken views/functions)
-- ==========================================================
DROP VIEW IF EXISTS public.order_details_v3 CASCADE;
DROP FUNCTION IF EXISTS public.get_unified_bootstrap_data(TEXT, TEXT);
DROP FUNCTION IF EXISTS public.update_delivery_location_v16(UUID, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION);

-- ==========================================================
-- 🏆 3. THE "TRUTH" VIEW (Fixes "Duplicate Column" Error)
-- ==========================================================
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
    
    -- Vendor Details
    v.name as vendor_name,
    v.address as vendor_address,
    v.phone as vendor_phone,
    v.image_url as vendor_image_url,
    COALESCE(o.pickup_lat, v.latitude) as resolved_pickup_lat,
    COALESCE(o.pickup_lng, v.longitude) as resolved_pickup_lng,
    
    -- Rider Details (Fixes TEXT vs UUID "Shell Operator" Error)
    dr.name as rider_name,
    dr.phone as rider_phone,
    dr.profile_image as rider_avatar,
    dr.rating as rider_rating,
    dr.vehicle_number as rider_vehicle,
    dr.current_lat as rider_live_lat,
    dr.current_lng as rider_live_lng,
    
    -- UI Display Logic
    CASE 
        WHEN lower(o.status) = 'placed' THEN 'Order Placed'
        WHEN lower(o.status) = 'accepted' THEN 'Order Accepted'
        WHEN lower(o.status) = 'preparing' THEN 'Chef is Cooking'
        WHEN lower(o.status) = 'ready' THEN 'Ready for Pickup'
        WHEN lower(o.status) = 'picked_up' THEN 'Rider Picked Food'
        WHEN lower(o.status) = 'on_the_way' THEN 'Rider is On The Way'
        WHEN lower(o.status) = 'delivered' THEN 'Delivered'
        ELSE UPPER(o.status)
    END as status_display,

    CASE 
        WHEN lower(o.status) IN ('placed', 'accepted') THEN 1
        WHEN lower(o.status) = 'preparing' THEN 2
        WHEN lower(o.status) IN ('ready', 'picked_up') THEN 3
        WHEN lower(o.status) = 'on_the_way' THEN 4
        WHEN lower(o.status) = 'delivered' THEN 5
        ELSE 1
    END as current_step

FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id::TEXT = v.id::TEXT
LEFT JOIN public.delivery_riders dr ON o.rider_id::TEXT = dr.id::TEXT;

-- ==========================================================
-- 🎯 4. LOGISTICS ENGINE (Functions)
-- ==========================================================

-- Master GPS Pulse
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
    -- Update Rider Realtime State
    UPDATE public.delivery_riders SET
        current_lat = p_lat,
        current_lng = p_lng,
        heading = p_heading,
        last_gps_update = now()
    WHERE id::TEXT = p_rider_id;

    -- Log Snapshot
    INSERT INTO public.order_live_tracking (order_id, rider_id, latitude, longitude, speed, heading)
    VALUES (p_order_id, p_rider_id::UUID, p_lat, p_lng, p_speed, p_heading);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Unified Data Fetcher
CREATE OR REPLACE FUNCTION public.get_unified_bootstrap_data(p_user_id TEXT, p_role TEXT DEFAULT 'customer')
RETURNS JSONB AS $$
DECLARE
    v_profile JSONB;
    v_orders JSONB;
BEGIN
    IF p_role = 'customer' THEN
        SELECT row_to_json(p)::jsonb INTO v_profile FROM public.customer_profiles p WHERE id::TEXT = p_user_id;
    ELSIF p_role = 'delivery' THEN
        SELECT row_to_json(r)::jsonb INTO v_profile FROM public.delivery_riders r WHERE id::TEXT = p_user_id;
    END IF;

    SELECT json_agg(o)::jsonb INTO v_orders 
    FROM (
        SELECT * FROM public.order_details_v3 
        WHERE (customer_id::TEXT = p_user_id OR rider_id::TEXT = p_user_id)
        ORDER BY created_at DESC 
        LIMIT 10
    ) o;

    RETURN jsonb_build_object(
        'profile', COALESCE(v_profile, '{}'::jsonb),
        'orders', COALESCE(v_orders, '[]'::jsonb)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==========================================================
-- ⚡ 5. REALTIME ENABLEMENT
-- ==========================================================
ALTER TABLE public.orders REPLICA IDENTITY FULL;
ALTER TABLE public.delivery_riders REPLICA IDENTITY FULL;
ALTER TABLE public.chat_messages REPLICA IDENTITY FULL;
ALTER TABLE public.order_live_tracking REPLICA IDENTITY FULL;

-- Re-publish correctly
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

GRANT SELECT ON public.order_details_v3 TO anon, authenticated, service_role;

COMMIT;
