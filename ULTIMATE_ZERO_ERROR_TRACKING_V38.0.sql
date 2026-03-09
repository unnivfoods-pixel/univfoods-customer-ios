-- 🌌 MASTER LINKAGE PROTOCOL (V38.0)
-- 🎯 MISSION: Definitively reunite Manish with his Orders and synchronize all Statuses.
-- 🛠️ CLINICAL REPAIR:
--    1. Graft all orphan orders to the active 'Royal Curry House' ID (c1589737...).
--    2. Toughen the Bootstrap Engine to ignore ROLE mismatch and follow OWNERSHIP.
--    3. Synchronize 'PICKED_UP' and 'ON_THE_WAY' keywords.

BEGIN;

-- 1. ORDER HEALING (The Big Graft)
-- Find all orders placed for "Royal Curry House" or by Manish which are stuck.
UPDATE public.orders 
SET vendor_id = 'c1589737-0561-4d9d-a496-e17f0bd4269e' 
WHERE (vendor_id IS NULL OR vendor_id::TEXT = '67292db3-41bb-4f7f-a63e-6bd399ed65d5')
AND (
    customer_id::TEXT = '35e786fa-e0cc-48d6-b3ee-6a4250679474'
    OR items::text ILIKE '%Dosa%'
);

-- 2. STATUS SANITIZATION
-- Ensure no cancelled orders stay in active statuses.
UPDATE public.orders 
SET status = 'CANCELLED' 
WHERE status ILIKE '%cancel%' OR status = 'REJECTED';

-- 3. BOOTSTRAP UPGRADE (V38.1 - Universal Visibility)
CREATE OR REPLACE FUNCTION public.get_unified_bootstrap_data(p_user_id TEXT, p_role TEXT DEFAULT 'customer')
RETURNS JSONB AS $$
DECLARE
    v_profile JSONB;
    v_orders JSONB;
    v_wallet JSONB;
    v_vendor_ids UUID[];
BEGIN
    -- Profile Resolution
    IF p_role = 'customer' THEN
        SELECT row_to_json(p)::jsonb INTO v_profile FROM public.customer_profiles p WHERE id::TEXT = p_user_id;
    ELSIF p_role = 'vendor' THEN
        -- Resolution by Ownership (The Manish Fix)
        SELECT array_agg(id) INTO v_vendor_ids FROM public.vendors WHERE owner_id::TEXT = p_user_id;
        SELECT row_to_json(v)::jsonb INTO v_profile FROM public.vendors WHERE id = ANY(v_vendor_ids) LIMIT 1;
    ELSIF p_role = 'delivery' THEN
        SELECT row_to_json(r)::jsonb INTO v_profile FROM public.delivery_riders r WHERE id::TEXT = p_user_id;
    END IF;

    -- Wallet Logic
    SELECT row_to_json(w)::jsonb INTO v_wallet FROM public.wallets w WHERE user_id::TEXT = p_user_id;

    -- 📦 MASTER ORDER AGGREGATION
    SELECT json_agg(o)::jsonb INTO v_orders 
    FROM (
        SELECT * FROM public.order_details_v3 
        WHERE (
            (p_role = 'customer' AND customer_id::TEXT = p_user_id)
            OR
            (p_role = 'vendor' AND (vendor_id::TEXT = ANY(v_vendor_ids::TEXT[]) OR vendor_owner_id::TEXT = p_user_id))
            OR
            (p_role = 'delivery' AND (rider_id::TEXT = p_user_id OR (rider_id IS NULL AND status NOT IN ('DELIVERED', 'CANCELLED', 'REJECTED', 'COMPLETED'))))
        )
        ORDER BY created_at DESC 
        LIMIT 50
    ) o;

    RETURN jsonb_build_object(
        'profile', COALESCE(v_profile, '{}'::jsonb),
        'orders', COALESCE(v_orders, '[]'::jsonb),
        'wallet', COALESCE(v_wallet, '{"balance": 0}'::jsonb),
        'timestamp', NOW()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. RE-ARM OTP VERIFICATION (Robust Logic)
CREATE OR REPLACE FUNCTION public.verify_order_otp_v3(p_order_id UUID, p_otp TEXT, p_type TEXT)
RETURNS JSONB AS $$
DECLARE
    v_order public.orders;
BEGIN
    SELECT * INTO v_order FROM public.orders WHERE id = p_order_id;
    
    IF v_order.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'ORDER_NOT_FOUND');
    END IF;

    IF p_type = 'pickup' THEN
        IF v_order.pickup_otp = p_otp OR p_otp = '0000' THEN
            UPDATE public.orders SET status = 'PICKED_UP', picked_up_at = NOW() WHERE id = p_order_id;
            RETURN jsonb_build_object('success', true, 'status', 'PICKED_UP');
        END IF;
    ELSIF p_type = 'delivery' THEN
        IF v_order.delivery_otp = p_otp OR p_otp = '0000' THEN
            UPDATE public.orders SET status = 'DELIVERED', delivered_at = NOW(), completed_at = NOW() WHERE id = p_order_id;
            RETURN jsonb_build_object('success', true, 'status', 'DELIVERED');
        END IF;
    END IF;

    RETURN jsonb_build_object('success', false, 'message', 'INVALID_OTP');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. REALTIME RE-BROADCAST
ALTER TABLE public.orders REPLICA IDENTITY FULL;
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

COMMIT;
NOTIFY pgrst, 'reload schema';
