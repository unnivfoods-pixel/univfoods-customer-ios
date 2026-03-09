-- 🛰️ THE ULTIMATE "ZERO-ERROR" TRACKING SYSTEM (V35.3) - VENDOR RECOVERY
-- 🎯 MISSION: Fix Vendor Sync, Bootstrap Support for Vendors, and Flattened Rider Data.

BEGIN;

-- 1. Unified Data Fetcher (FIXED FOR VENDORS)
CREATE OR REPLACE FUNCTION public.get_unified_bootstrap_data(p_user_id TEXT, p_role TEXT DEFAULT 'customer')
RETURNS JSONB AS $$
DECLARE
    v_profile JSONB;
    v_orders JSONB;
BEGIN
    -- Profile Selection based on role
    IF p_role = 'customer' THEN
        SELECT row_to_json(p)::jsonb INTO v_profile FROM public.customer_profiles p WHERE id::TEXT = p_user_id;
    ELSIF p_role = 'delivery' THEN
        SELECT row_to_json(r)::jsonb INTO v_profile FROM public.delivery_riders r WHERE id::TEXT = p_user_id;
    ELSIF p_role = 'vendor' THEN
        SELECT row_to_json(v)::jsonb INTO v_profile FROM public.vendors v WHERE id::TEXT = p_user_id;
    END IF;

    -- Active Orders Selection from the robust view (NOW INCLUDES VENDOR FILTER)
    SELECT json_agg(o)::jsonb INTO v_orders 
    FROM (
        SELECT * FROM public.order_details_v3 
        WHERE (
            customer_id::TEXT = p_user_id OR 
            rider_id::TEXT = p_user_id OR 
            vendor_id::TEXT = p_user_id
        )
        ORDER BY created_at DESC 
        LIMIT 20 -- Increased limit for busy vendors
    ) o;

    RETURN jsonb_build_object(
        'profile', COALESCE(v_profile, '{}'::jsonb),
        'orders', COALESCE(v_orders, '[]'::jsonb)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Ensure Realtime is ACTIVE for all critical tables
ALTER TABLE public.orders REPLICA IDENTITY FULL;
-- Re-publish correctly to ensure Vendor and Rider get updates
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

COMMIT;
