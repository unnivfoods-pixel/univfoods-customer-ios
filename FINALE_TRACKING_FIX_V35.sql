-- 🛰️ ULTIMATE LOGISTICS & TRACKING FIX (V35.0)
-- 🎯 MISSION: Resolve "Duplicate Column" and "Type Mismatch" (Shell Operator) errors.
-- This script replaces all previous tracking/address fixes with a unified stable version.

BEGIN;

-- 1. 📋 TABLE HARMONIZATION
-- Ensure the base columns exist with correct types.
DO $$ 
BEGIN
    -- Add columns to orders if missing
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='delivery_address') THEN
        ALTER TABLE public.orders ADD COLUMN delivery_address TEXT;
    END IF;
    
    -- Ensure rider_id is present
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='rider_id') THEN
        ALTER TABLE public.orders ADD COLUMN rider_id UUID;
    END IF;
END $$;

-- 2. ⚡ REAL-TIME GPS REPAIR
-- Ensure delivery_riders has the high-fidelity tracking columns
DO $$ 
BEGIN
    ALTER TABLE public.delivery_riders ADD COLUMN IF NOT EXISTS current_lat DOUBLE PRECISION;
    ALTER TABLE public.delivery_riders ADD COLUMN IF NOT EXISTS current_lng DOUBLE PRECISION;
    ALTER TABLE public.delivery_riders ADD COLUMN IF NOT EXISTS heading DOUBLE PRECISION DEFAULT 0;
    ALTER TABLE public.delivery_riders ADD COLUMN IF NOT EXISTS last_gps_update TIMESTAMPTZ;
END $$;

-- 3. 🛡️ DROP CONFLICTING VIEW (Clean Slate)
DROP VIEW IF EXISTS public.order_details_v3 CASCADE;

-- 4. 🏆 THE "TRUTH" VIEW (Explicit Column Mapping)
-- Using explicit columns to avoid "specified more than once" errors from o.*
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
    o.cooking_instructions,
    o.created_at,
    o.delivered_at,
    
    -- Calculated Address
    COALESCE(NULLIF(o.delivery_address, '{}'), o.address, 'My Address') as effective_address,
    
    -- Joined Vendor Info
    v.name as vendor_name,
    v.address as vendor_address,
    v.phone as vendor_phone,
    v.image_url as vendor_image_url,
    COALESCE(o.pickup_lat, v.latitude) as resolved_pickup_lat,
    COALESCE(o.pickup_lng, v.longitude) as resolved_pickup_lng,
    
    -- Joined Rider Info (Casting IDs to TEXT to avoid Shell Operator error)
    dr.name as rider_name,
    dr.phone as rider_phone,
    dr.profile_image as rider_avatar,
    dr.rating as rider_rating,
    dr.vehicle_number as rider_vehicle,
    dr.current_lat as rider_live_lat,
    dr.current_lng as rider_live_lng,
    
    -- UI Status Labels
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

    -- 5-Step Progress Logic
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

GRANT SELECT ON public.order_details_v3 TO anon, authenticated, service_role;

-- 5. 🎯 MASTER GPS UPDATE RPC (Final Version)
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
    UPDATE public.delivery_riders SET
        current_lat = p_lat,
        current_lng = p_lng,
        heading = p_heading,
        last_gps_update = now()
    WHERE id::TEXT = p_rider_id;

    -- Update Order Coordinates for quick lookup
    UPDATE public.orders SET
        delivery_lat = p_lat,
        delivery_lng = p_lng
    WHERE id = p_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. 🔄 BOOTSTRAP REFRESH (Fixed for Type Safety)
DROP FUNCTION IF EXISTS public.get_unified_bootstrap_data(TEXT, TEXT);
CREATE OR REPLACE FUNCTION public.get_unified_bootstrap_data(p_user_id TEXT, p_role TEXT DEFAULT 'customer')
RETURNS JSONB AS $$
DECLARE
    v_profile JSONB;
    v_orders JSONB;
BEGIN
    -- Profile Selection
    IF p_role = 'customer' THEN
        SELECT row_to_json(p)::jsonb INTO v_profile FROM public.customer_profiles p WHERE id::TEXT = p_user_id;
    ELSIF p_role = 'delivery' THEN
        SELECT row_to_json(r)::jsonb INTO v_profile FROM public.delivery_riders r WHERE id::TEXT = p_user_id;
    END IF;

    -- Active Orders Selection from the robust view
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

COMMIT;
