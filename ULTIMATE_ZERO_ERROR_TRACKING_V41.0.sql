-- 🌌 MISSION: THE MANISH RESTORATION (V41.0)
-- 🎯 GOAL: Fix Vendor visibility by unifying Manish's ID and Shop ownership.
-- 🛠️ DISCOVERY: Manish's login ID is 35e786fa-e0cc-48d6-b3ee-6a4250679474.
--           The shop was pointing to a ghost ID (c1692237...).

BEGIN;

-- 1. SHOP RE-POSSESSION
-- Reunite Manish with his primary shop 'Royal Curry House'.
UPDATE public.vendors 
SET owner_id = '35e786fa-e0cc-48d6-b3ee-6a4250679474' 
WHERE id = 'c1589737-0561-4d9d-a499-214655f16992' 
OR name ILIKE '%Royal Curry House%';

-- 2. ORDER LINKAGE REPAIR
-- Graft all orders from recent tests back to the correct Vendor ID.
UPDATE public.orders 
SET vendor_id = 'c1589737-0561-4d9d-a499-214655f16992' 
WHERE customer_id = '35e786fa-e0cc-48d6-b3ee-6a4250679474'
AND (vendor_id IS NULL OR vendor_id::text ILIKE '67292%');

-- 3. THE "TRUTH" VIEW UPGRADE (V41)
-- Force drop needed because we are changing column structure.
DROP VIEW IF EXISTS public.order_details_v3 CASCADE;

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
    o.delivery_address,
    o.delivery_lat,
    o.delivery_lng,
    o.pickup_otp,
    o.delivery_otp,
    o.created_at,
    
    -- Calculated Address
    COALESCE(o.delivery_address, 'My Address') as effective_address,
    
    -- Vendor details
    v.name as vendor_name,
    v.address as vendor_address,
    v.owner_id as vendor_owner_id, -- CRITICAL: Real-time owner link
    
    -- Customer Details
    cp.full_name as customer_name,
    cp.phone as customer_phone,
    
    -- UI Display Logic
    CASE 
        WHEN lower(o.status) = 'placed' THEN 'Order Placed'
        WHEN lower(o.status) = 'accepted' THEN 'Accepted'
        WHEN lower(o.status) = 'preparing' THEN 'Chef is Cooking'
        WHEN lower(o.status) = 'ready' THEN 'Ready for Pickup'
        WHEN lower(o.status) = 'picked_up' THEN 'Rider Picked Food'
        WHEN lower(o.status) = 'on_the_way' THEN 'Out for Delivery'
        WHEN lower(o.status) = 'delivered' THEN 'Delivered'
        ELSE UPPER(o.status)
    END as status_display

FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id = v.id
LEFT JOIN public.customer_profiles cp ON o.customer_id = cp.id;

-- 4. BOOTSTRAP ENGINE (V41 - Ultra-Reliable)
CREATE OR REPLACE FUNCTION public.get_unified_bootstrap_data(p_user_id TEXT, p_role TEXT DEFAULT 'customer')
RETURNS JSONB AS $$
DECLARE
    v_profile JSONB;
    v_orders JSONB;
    v_wallet JSONB;
BEGIN
    -- 1. Profile Fetching
    IF p_role = 'customer' THEN
        SELECT row_to_json(p)::jsonb INTO v_profile FROM public.customer_profiles p WHERE id::TEXT = p_user_id;
    ELSIF p_role = 'vendor' THEN
        -- Resolve Vendor by Owner ID
        SELECT row_to_json(v)::jsonb INTO v_profile FROM public.vendors v WHERE owner_id::TEXT = p_user_id LIMIT 1;
    ELSIF p_role = 'delivery' THEN
        SELECT row_to_json(r)::jsonb INTO v_profile FROM public.delivery_riders r WHERE id::TEXT = p_user_id;
    END IF;

    -- 2. Wallet
    SELECT row_to_json(w)::jsonb INTO v_wallet FROM public.wallets w WHERE user_id::TEXT = p_user_id;

    -- 3. 📦 MASTER ORDER AGGREGATION
    SELECT json_agg(o)::jsonb INTO v_orders 
    FROM (
        SELECT * FROM public.order_details_v3 
        WHERE (
            (customer_id::TEXT = p_user_id)
            OR
            (vendor_owner_id::TEXT = p_user_id)
            OR
            (p_role = 'delivery' AND (rider_id::TEXT = p_user_id OR (rider_id IS NULL AND status IN ('PLACED', 'ACCEPTED', 'READY'))))
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

-- 5. REALTIME ARMAMENT
ALTER TABLE public.orders REPLICA IDENTITY FULL;
ALTER TABLE public.vendors REPLICA IDENTITY FULL;
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

COMMIT;
NOTIFY pgrst, 'reload schema';
