-- 🛰️ THE ULTIMATE "ZERO-ERROR" TRACKING SYSTEM (V35.6) - GLOBAL MISSION SYNC
-- 🎯 MISSION: Fix "Available Missions" visibility for Riders and "Lost Orders" for Vendors.

BEGIN;

-- 1. 🏆 THE "GLOBAL" DATA ENGINE (Highly Optimized)
CREATE OR REPLACE FUNCTION public.get_unified_bootstrap_data(p_user_id TEXT, p_role TEXT DEFAULT 'customer')
RETURNS JSONB AS $$
DECLARE
    v_profile JSONB;
    v_orders JSONB;
    v_actual_id UUID;
    v_vendor_uuid UUID;
BEGIN
    -- IDENTITY MAPPING
    IF p_role = 'customer' THEN
        SELECT row_to_json(p)::jsonb INTO v_profile FROM public.customer_profiles p WHERE id::TEXT = p_user_id;
        v_actual_id := CASE WHEN p_user_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN p_user_id::UUID ELSE NULL END;
    ELSIF p_role = 'delivery' THEN
        SELECT row_to_json(r)::jsonb INTO v_profile FROM public.delivery_riders r WHERE id::TEXT = p_user_id;
        v_actual_id := CASE WHEN p_user_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN p_user_id::UUID ELSE NULL END;
    ELSIF p_role = 'vendor' THEN
        -- Vendors are matched by owner_id (Auth ID)
        SELECT id INTO v_vendor_uuid FROM public.vendors WHERE owner_id::TEXT = p_user_id LIMIT 1;
        
        -- Fallback: If no owner_id match, try direct ID match (for alternate login methods)
        IF v_vendor_uuid IS NULL AND p_user_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
            v_vendor_uuid := p_user_id::UUID;
        END IF;

        SELECT row_to_json(v)::jsonb INTO v_profile FROM public.vendors v WHERE id = v_vendor_uuid;
        v_actual_id := v_vendor_uuid;
    END IF;

    -- COMPLEX ORDER AGGREGATION
    SELECT json_agg(o)::jsonb INTO v_orders 
    FROM (
        SELECT * FROM public.order_details_v3 
        WHERE (
            -- 1. Customer's own orders
            (p_role = 'customer' AND customer_id::TEXT = p_user_id)
            
            OR
            
            -- 2. Vendor's own orders (Using resolved UUID)
            (p_role = 'vendor' AND vendor_id = v_actual_id)
            
            OR
            
            -- 3. Delivery Rider's Scope
            (p_role = 'delivery' AND (
                -- Their active mission
                rider_id::TEXT = p_user_id 
                OR 
                -- Available MISSIONS (Waiting for rider)
                (rider_id IS NULL AND status IN ('PLACED', 'ACCEPTED', 'READY_FOR_PICKUP', 'SEARCHING_FOR_PARTNER'))
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
