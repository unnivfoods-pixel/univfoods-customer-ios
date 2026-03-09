-- 📡 EMERGENCY ORDER RECOVERY (V11.9.6)
-- Purpose: Recover "missing" orders and ensure Demo Vendor sees everything for "Curry Point"

BEGIN;

-- 1. IDENTIFY & RECLAIM CURRY POINT VENDOR
-- If 'srivilliputhur curry points' exists, link it to the demo account.
UPDATE public.vendors 
SET owner_id = '00000000-0000-0000-0000-000000000001'::uuid
WHERE name ILIKE '%curry%';

-- 2. RECOVER DANGLING ORDERS
-- The order 'eab01f49...' was lost because its vendor_id didn't exist in the sanitized table.
-- We re-assign it to the stable Demo Vendor ID.
UPDATE public.orders 
SET vendor_id = '11111111-1111-1111-1111-111111111111'::uuid
WHERE vendor_id NOT IN (SELECT id FROM public.vendors)
   OR vendor_id = '60ad6fb6-b308-4b0a-9d74-5314463f35a5'::uuid;

-- 3. ENSURE STABLE BOOTSTRAP (v5)
-- Be inclusive of all status strings (case-insensitive done in app, but filtering here too)
CREATE OR REPLACE FUNCTION public.get_unified_bootstrap_data(p_user_id TEXT, p_role TEXT)
RETURNS JSON AS $$
DECLARE
    v_profile JSON;
    v_active_orders JSON;
    v_vendor_ids UUID[];
BEGIN
    IF p_role = 'vendor' THEN
        -- Get ALL vendors owned by this user
        SELECT array_agg(id) INTO v_vendor_ids FROM public.vendors WHERE owner_id::text = p_user_id;
        
        -- Primary Profile
        SELECT row_to_json(v) INTO v_profile FROM public.vendors WHERE id = ANY(v_vendor_ids) LIMIT 1;
        
        IF v_vendor_ids IS NOT NULL THEN
            SELECT json_agg(o) INTO v_active_orders FROM public.order_details_v3 o 
            WHERE o.vendor_id = ANY(v_vendor_ids)
            AND lower(o.status) NOT IN ('delivered', 'cancelled', 'rejected');
        END IF;
    ELSIF p_role = 'customer' THEN
        SELECT row_to_json(p) INTO v_profile FROM public.customer_profiles p WHERE p.id::text = p_user_id;
        SELECT json_agg(o) INTO v_active_orders FROM public.order_details_v3 o WHERE o.customer_id = p_user_id AND lower(o.status) NOT IN ('delivered', 'cancelled', 'rejected');
    END IF;

    RETURN json_build_object(
        'profile', COALESCE(v_profile, '{}'::json),
        'orders', COALESCE(v_active_orders, '[]'::json)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
