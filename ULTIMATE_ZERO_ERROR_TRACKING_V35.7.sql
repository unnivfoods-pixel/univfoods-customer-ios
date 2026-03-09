-- 🛰️ THE ULTIMATE "ZERO-ERROR" TRACKING SYSTEM (V35.7) - EMERGENCY RECOVERY
-- 🎯 MISSION: Restore broken visibility for Vendors & Riders. Solve "Awaiting Rider" stuck state.

BEGIN;

-- 1. 🏆 THE "TRUTH" VIEW (Stable & Flattened)
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
    
    -- Customer Details
    cp.full_name as customer_name,
    cp.phone as customer_phone,
    cp.avatar_url as customer_avatar,

    -- Rider Details
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
        WHEN lower(o.status) IN ('accepted', 'rider_assigned') THEN 'Order Accepted'
        WHEN lower(o.status) = 'preparing' THEN 'Chef is Cooking'
        WHEN lower(o.status) IN ('ready', 'ready_for_pickup') THEN 'Ready for Pickup'
        WHEN lower(o.status) IN ('picked_up', 'picking_up') THEN 'Rider Picked Food'
        WHEN lower(o.status) = 'on_the_way' THEN 'Rider is On The Way'
        WHEN lower(o.status) = 'delivered' THEN 'Delivered'
        ELSE UPPER(REPLACE(o.status, '_', ' '))
    END as status_display,

    CASE 
        WHEN lower(o.status) = 'placed' THEN 1
        WHEN lower(o.status) IN ('accepted', 'rider_assigned') THEN 2
        WHEN lower(o.status) = 'preparing' THEN 3
        WHEN lower(o.status) IN ('ready', 'ready_for_pickup') THEN 4
        WHEN lower(o.status) IN ('picked_up', 'picking_up') THEN 5
        WHEN lower(o.status) = 'on_the_way' THEN 6
        WHEN lower(o.status) = 'delivered' THEN 7
        ELSE 1
    END as current_step

FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id::TEXT = v.id::TEXT
LEFT JOIN public.delivery_riders dr ON o.rider_id::TEXT = dr.id::TEXT
LEFT JOIN public.customer_profiles cp ON o.customer_id::TEXT = cp.id::TEXT;

-- 2. 🏆 THE "GLOBAL" DATA ENGINE (High Performance & Anti-Crash)
CREATE OR REPLACE FUNCTION public.get_unified_bootstrap_data(p_user_id TEXT, p_role TEXT DEFAULT 'customer')
RETURNS JSONB AS $$
DECLARE
    v_profile JSONB;
    v_orders JSONB;
    v_resolved_vendor_id TEXT;
BEGIN
    -- 1. Identity Resolution
    IF p_role = 'vendor' THEN
        -- Map Owner ID to Vendor ID
        SELECT id::TEXT INTO v_resolved_vendor_id FROM public.vendors WHERE owner_id::TEXT = p_user_id LIMIT 1;
        -- Fallback to direct ID
        IF v_resolved_vendor_id IS NULL THEN v_resolved_vendor_id := p_user_id; END IF;
        
        SELECT row_to_json(v)::jsonb INTO v_profile FROM public.vendors v WHERE id::TEXT = v_resolved_vendor_id;
    ELSIF p_role = 'delivery' THEN
        SELECT row_to_json(r)::jsonb INTO v_profile FROM public.delivery_riders r WHERE id::TEXT = p_user_id;
    ELSE
        SELECT row_to_json(p)::jsonb INTO v_profile FROM public.customer_profiles p WHERE id::TEXT = p_user_id;
    END IF;

    -- 2. Universal Order Fetching (RELAXED TYPES)
    SELECT json_agg(o)::jsonb INTO v_orders 
    FROM (
        SELECT * FROM public.order_details_v3 
        WHERE (
            -- Customer Scope
            (p_role = 'customer' AND customer_id::TEXT = p_user_id)
            OR
            -- Vendor Scope
            (p_role = 'vendor' AND vendor_id::TEXT = v_resolved_vendor_id)
            OR
            -- Delivery Scope
            (p_role = 'delivery' AND (
                rider_id::TEXT = p_user_id -- Assigned
                OR 
                (rider_id IS NULL AND status IN ('PLACED', 'ACCEPTED', 'READY_FOR_PICKUP', 'SEARCHING_FOR_PARTNER')) -- Unassigned
            ))
        )
        ORDER BY created_at DESC 
        LIMIT 50
    ) o;

    RETURN jsonb_build_object(
        'profile', COALESCE(v_profile, '{}'::jsonb),
        'orders', COALESCE(v_orders, '[]'::jsonb)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_unified_bootstrap_data(TEXT, TEXT) TO anon, authenticated, service_role;

COMMIT;
