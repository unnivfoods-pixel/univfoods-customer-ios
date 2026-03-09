-- 🛰️ THE ULTIMATE "ZERO-ERROR" TRACKING SYSTEM (V35.4) - VENDOR IDENTITY RECOVERY
-- 🎯 MISSION: Fix Vendor Data Visibility and Dynamic ID Mapping.

BEGIN;

-- 1. Unified Data Fetcher (IDENTITY AWARE)
CREATE OR REPLACE FUNCTION public.get_unified_bootstrap_data(p_user_id TEXT, p_role TEXT DEFAULT 'customer')
RETURNS JSONB AS $$
DECLARE
    v_profile JSONB;
    v_orders JSONB;
    v_actual_vendor_id UUID;
BEGIN
    -- Profile Selection & Identity Mapping
    IF p_role = 'customer' THEN
        SELECT row_to_json(p)::jsonb INTO v_profile FROM public.customer_profiles p WHERE id::TEXT = p_user_id;
    ELSIF p_role = 'delivery' THEN
        SELECT row_to_json(r)::jsonb INTO v_profile FROM public.delivery_riders r WHERE id::TEXT = p_user_id;
    ELSIF p_role = 'vendor' THEN
        -- Vendors are matched by owner_id (Auth ID)
        SELECT id INTO v_actual_vendor_id FROM public.vendors WHERE owner_id::TEXT = p_user_id LIMIT 1;
        SELECT row_to_json(v)::jsonb INTO v_profile FROM public.vendors v WHERE id = v_actual_vendor_id;
    END IF;

    -- Active Orders Selection from the robust view
    SELECT json_agg(o)::jsonb INTO v_orders 
    FROM (
        SELECT * FROM public.order_details_v3 
        WHERE (
            customer_id::TEXT = p_user_id OR 
            rider_id::TEXT = p_user_id OR 
            vendor_id::TEXT = p_user_id OR
            vendor_id = v_actual_vendor_id -- Match by resolved vendor ID for owners
        )
        ORDER BY created_at DESC 
        LIMIT 20 
    ) o;

    RETURN jsonb_build_object(
        'profile', COALESCE(v_profile, '{}'::jsonb),
        'orders', COALESCE(v_orders, '[]'::jsonb)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Repair Realtime Publication (Critical for sync)
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

COMMIT;
