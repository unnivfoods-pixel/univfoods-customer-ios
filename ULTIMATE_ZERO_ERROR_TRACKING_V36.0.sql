-- 🛰️ THE ULTIMATE "ZERO-ERROR" TRACKING SYSTEM (V36.0) - SUPREME HARMONY
-- 🎯 MISSION: Fix "Disappearing Orders", "Radar Loop", and "Realtime Visibility".
-- 🛠️ FIXES: Case-insensitive status, relaxed type comparisons, and full scope bootstrap.

BEGIN;

-- ==========================================================
-- 🏗️ 1. INFRASTRUCTURE REPAIR & CLEAN SLATE
-- ==========================================================
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMPTZ;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ;

DROP VIEW IF EXISTS public.order_details_v3 CASCADE;
DROP FUNCTION IF EXISTS public.get_unified_bootstrap_data(TEXT, TEXT);

-- ==========================================================
-- 🏆 2. THE "TRUTH" VIEW (Ultra-Robust Version)
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
    o.completed_at,
    o.eta_minutes,
    
    -- Calculated Address
    COALESCE(NULLIF(o.delivery_address, '{}'), o.address, 'My Address') as effective_address,
    
    -- Vendor Details
    v.name as vendor_name,
    v.address as vendor_address,
    v.phone as vendor_phone,
    v.image_url as vendor_image_url,
    v.owner_id as vendor_owner_id,
    COALESCE(o.pickup_lat, v.latitude) as resolved_pickup_lat,
    COALESCE(o.pickup_lng, v.longitude) as resolved_pickup_lng,
    
    -- Rider Details
    dr.name as rider_name,
    dr.phone as rider_phone,
    dr.profile_image as rider_avatar,
    dr.rating as rider_rating,
    dr.vehicle_number as rider_vehicle,
    dr.current_lat as rider_live_lat,
    dr.current_lng as rider_live_lng,

    -- Customer Details
    cp.full_name as customer_name,
    cp.phone as customer_phone,
    
    -- UI Display Logic (Case-Insensitive)
    CASE 
        WHEN UPPER(o.status) = 'PLACED' THEN 'Order Placed'
        WHEN UPPER(o.status) = 'ACCEPTED' THEN 'Order Accepted'
        WHEN UPPER(o.status) = 'PREPARING' THEN 'Chef is Cooking'
        WHEN UPPER(o.status) = 'READY_FOR_PICKUP' THEN 'Ready for Pickup'
        WHEN UPPER(o.status) = 'RIDER_ASSIGNED' THEN 'Rider Assigned'
        WHEN UPPER(o.status) = 'PICKING_UP' THEN 'Rider at Restaurant'
        WHEN UPPER(o.status) = 'PICKED_UP' THEN 'Rider Picked Food'
        WHEN UPPER(o.status) = 'ON_THE_WAY' THEN 'Rider is On The Way'
        WHEN UPPER(o.status) = 'DELIVERED' THEN 'Delivered'
        ELSE UPPER(o.status)
    END as status_display,

    CASE 
        WHEN UPPER(o.status) IN ('PLACED', 'ACCEPTED') THEN 1
        WHEN UPPER(o.status) = 'PREPARING' THEN 2
        WHEN UPPER(o.status) IN ('READY_FOR_PICKUP', 'RIDER_ASSIGNED', 'PICKING_UP') THEN 3
        WHEN UPPER(o.status) IN ('PICKED_UP', 'ON_THE_WAY') THEN 4
        WHEN UPPER(o.status) = 'DELIVERED' THEN 5
        ELSE 1
    END as current_step

FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id::TEXT = v.id::TEXT
LEFT JOIN public.delivery_riders dr ON o.rider_id::TEXT = dr.id::TEXT
LEFT JOIN public.customer_profiles cp ON o.customer_id::TEXT = cp.id::TEXT;

GRANT SELECT ON public.order_details_v3 TO anon, authenticated, service_role;

-- ==========================================================
-- 🎯 3. UNIFIED BOOTSTRAP ENGINE (The Order Ghost Finder)
-- ==========================================================
CREATE OR REPLACE FUNCTION public.get_unified_bootstrap_data(p_user_id TEXT, p_role TEXT DEFAULT 'customer')
RETURNS JSONB AS $$
DECLARE
    v_profile JSONB;
    v_orders JSONB;
    v_resolved_vendor_id UUID;
BEGIN
    -- 1. Identify User Profile
    IF p_role = 'customer' THEN
        SELECT row_to_json(p)::jsonb INTO v_profile FROM public.customer_profiles p WHERE id::TEXT = p_user_id;
    ELSIF p_role = 'vendor' THEN
        SELECT id INTO v_resolved_vendor_id FROM public.vendors WHERE owner_id::TEXT = p_user_id;
        SELECT row_to_json(v)::jsonb INTO v_profile FROM public.vendors WHERE id = v_resolved_vendor_id;
    ELSIF p_role = 'delivery' THEN
        SELECT row_to_json(r)::jsonb INTO v_profile FROM public.delivery_riders r WHERE id::TEXT = p_user_id;
    END IF;

    -- 2. Universal Order Fetching (RELAXED TYPES + CASE INSENSITIVE)
    SELECT json_agg(o)::jsonb INTO v_orders 
    FROM (
        SELECT * FROM public.order_details_v3 
        WHERE (
            -- Customer Scope: Show all their orders
            (p_role = 'customer' AND customer_id::TEXT = p_user_id)
            OR
            -- Vendor Scope: Show orders for their assigned vendor ID
            (p_role = 'vendor' AND vendor_id::TEXT = v_resolved_vendor_id::TEXT)
            OR
            -- Delivery Scope: Show assigned missions OR unassigned available missions
            (p_role = 'delivery' AND (
                rider_id::TEXT = p_user_id -- Specifically assigned to this rider
                OR 
                (rider_id IS NULL AND UPPER(status) IN ('PLACED', 'ACCEPTED', 'READY_FOR_PICKUP', 'SEARCHING_FOR_PARTNER')) -- General available missions
            ))
        )
        AND UPPER(status) != 'DELIVERED' -- Keep list clean for active apps
        ORDER BY created_at DESC 
        LIMIT 50
    ) o;

    RETURN jsonb_build_object(
        'profile', COALESCE(v_profile, '{}'::jsonb),
        'orders', COALESCE(v_orders, '[]'::jsonb)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==========================================================
-- ⚡ 4. REALTIME ENABLEMENT
-- ==========================================================
-- Ensure DB broadcasts payloads
ALTER TABLE public.orders REPLICA IDENTITY FULL;
ALTER TABLE public.vendors REPLICA IDENTITY FULL;
ALTER TABLE public.delivery_riders REPLICA IDENTITY FULL;

-- Refresh Publication
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

COMMIT;

-- Signal PostgREST to reload
NOTIFY pgrst, 'reload schema';
