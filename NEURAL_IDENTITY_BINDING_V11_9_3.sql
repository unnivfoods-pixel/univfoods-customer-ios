-- 📡 NEURAL REPAIR & SYNC (V11.9.3)
-- FIX: Linking Demo Vendors and Riders to Production Identities

BEGIN;

-- 1. ADJUST VENDORS SCHEMA (Allow TEXT owner_id for demo flexibility if needed, or just link)
-- We'll stay with UUID but use a consistent DEMO identity.
-- Update Royal Curry House to be owned by our demo account.
UPDATE public.vendors 
SET owner_id = '00000000-0000-0000-0000-000000000001'::uuid
WHERE name = 'Royal Curry House';

-- 2. ENSURE RIDER LINKAGE
-- If delivery_riders table exists, ensure a demo rider exists with our demo ID.
INSERT INTO public.delivery_riders (id, name, phone, is_approved, is_online)
VALUES ('00000000-0000-0000-0000-000000000002'::uuid, 'Demo Rider', '9999999999', true, true)
ON CONFLICT (id) DO UPDATE SET is_approved = true, is_online = true;

-- 3. FIX BOOTSTRAP RPC (Ensure it handles NULL cases gently)
CREATE OR REPLACE FUNCTION public.get_unified_bootstrap_data(p_user_id TEXT, p_role TEXT)
RETURNS JSON AS $$
DECLARE
    v_profile JSON;
    v_active_orders JSON;
    v_wallet JSON;
    v_vendor_id UUID;
BEGIN
    -- Fetch Role-Specific Profile
    IF p_role = 'customer' THEN
        SELECT row_to_json(p) INTO v_profile FROM public.customer_profiles p WHERE p.id::text = p_user_id;
        SELECT json_agg(o) INTO v_active_orders FROM public.order_details_v3 o WHERE o.customer_id = p_user_id AND o.status NOT IN ('DELIVERED', 'CANCELLED');
    ELSIF p_role = 'vendor' THEN
        -- Link by owner_id OR direct ID (for legacy/demo)
        SELECT id INTO v_vendor_id FROM public.vendors v WHERE v.owner_id::text = p_user_id OR v.id::text = p_user_id LIMIT 1;
        SELECT row_to_json(v) INTO v_profile FROM public.vendors v WHERE v.id = v_vendor_id;
        
        IF v_vendor_id IS NOT NULL THEN
            SELECT json_agg(o) INTO v_active_orders FROM public.order_details_v3 o 
            WHERE o.vendor_id = v_vendor_id 
            AND o.status NOT IN ('DELIVERED', 'CANCELLED');
        END IF;
    ELSIF p_role = 'delivery' THEN
        SELECT row_to_json(r) INTO v_profile FROM public.delivery_riders r WHERE r.id::text = p_user_id;
        SELECT json_agg(o) INTO v_active_orders FROM public.order_details_v3 o WHERE o.rider_id::text = p_user_id AND o.status NOT IN ('DELIVERED', 'CANCELLED');
    END IF;

    -- Fetch Wallet
    SELECT row_to_json(w) INTO v_wallet FROM public.wallets w WHERE w.user_id::text = p_user_id;

    RETURN json_build_object(
        'profile', COALESCE(v_profile, '{}'::json),
        'orders', COALESCE(v_active_orders, '[]'::json),
        'wallet', COALESCE(v_wallet, '{"balance": 0}'::json)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
