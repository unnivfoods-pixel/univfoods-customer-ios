-- 🌍 THE GLOBAL PRODUCTION ENGINE V45.0
-- 🎯 MISSION: 100% Generic Real-time. No hardcoding. No single-user logic.
-- 🛠️ ARCHITECTURE: Dynamics joins and Global Real-time Publications.

BEGIN;

-- 1. CLEANUP ALL LEGACY/STAGING AMBIGUITIES (Safety First)
DROP VIEW IF EXISTS public.order_details_v3 CASCADE;
DROP FUNCTION IF EXISTS public.get_unified_bootstrap_data(TEXT, TEXT);
DROP FUNCTION IF EXISTS public.get_unified_bootstrap_data(TEXT);
DROP FUNCTION IF EXISTS public.verify_order_otp_v5(UUID, TEXT, TEXT);

-- 2. DYNAMIC TRUTH VIEW (Universal for every Customer, Vendor, and Rider)
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
    o.confirmed_at,
    o.accepted_at,
    o.prepared_at,
    o.ready_at,
    o.picked_up_at,
    o.delivered_at,
    o.cancelled_at,
    
    -- Dynamic Field Handling
    COALESCE(o.delivery_address, 'Pick-up point') as effective_address,
    v.name as vendor_name,
    v.address as vendor_address,
    v.phone as vendor_phone,
    v.owner_id as vendor_owner_id, -- DYNAMIC: Links ANY logged-in person to their shop
    v.latitude as vendor_lat,
    v.longitude as vendor_lng,
    
    cp.full_name as customer_name,
    cp.phone as customer_phone,
    
    dr.name as rider_name,
    dr.phone as rider_phone,
    dr.current_lat as rider_live_lat,
    dr.current_lng as rider_live_lng,
    dr.heading as rider_heading,
    
    -- Universal UI State Logic
    CASE 
        WHEN o.status = 'PAYMENT_PENDING' THEN 'Waiting for Payment'
        WHEN o.status = 'PLACED' THEN 'New Order Received'
        WHEN o.status = 'ACCEPTED' THEN 'Vendor Accepted'
        WHEN o.status = 'PREPARING' THEN 'Preparing Food'
        WHEN o.status = 'READY_FOR_PICKUP' THEN 'Ready for Pickup'
        WHEN o.status = 'RIDER_ASSIGNED' THEN 'Rider Assigned'
        WHEN o.status = 'PICKED_UP' THEN 'Order Picked Up'
        WHEN o.status = 'ON_THE_WAY' THEN 'On the Way'
        WHEN o.status = 'DELIVERED' THEN 'Successfully Delivered'
        WHEN o.status = 'CANCELLED' THEN 'Order Cancelled'
        ELSE UPPER(o.status)
    END as status_display

FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id = v.id
LEFT JOIN public.customer_profiles cp ON o.customer_id = cp.id
LEFT JOIN public.delivery_riders dr ON (o.rider_id::text = dr.id::text);

-- 3. GLOBAL BOOTSTRAP ENGINE (DYNAMIC FOR ANY USER)
CREATE OR REPLACE FUNCTION public.get_unified_bootstrap_data(p_user_id TEXT, p_role TEXT DEFAULT 'customer')
RETURNS JSONB AS $$
DECLARE
    v_profile JSONB;
    v_orders JSONB;
    v_wallet JSONB;
BEGIN
    -- Profile Resolution
    IF p_role = 'customer' THEN
        SELECT row_to_json(p)::jsonb INTO v_profile FROM public.customer_profiles p WHERE id::TEXT = p_user_id;
    ELSIF p_role = 'vendor' THEN
        -- Link ANY logged-in user to their dynamic vendor assignment
        SELECT row_to_json(v)::jsonb INTO v_profile FROM public.vendors v WHERE owner_id::TEXT = p_user_id LIMIT 1;
    ELSIF p_role = 'delivery' THEN
        SELECT row_to_json(r)::jsonb INTO v_profile FROM public.delivery_riders r WHERE id::TEXT = p_user_id;
    END IF;

    -- Financials
    SELECT row_to_json(w)::jsonb INTO v_wallet FROM public.wallets w WHERE user_id::TEXT = p_user_id;

    -- Master Order Flow (Dynamic Filters)
    SELECT json_agg(o)::jsonb INTO v_orders 
    FROM (
        SELECT * FROM public.order_details_v3 
        WHERE (
            -- 1. Any Customer sees their own orders
            (customer_id::TEXT = p_user_id) 
            OR
            -- 2. Any Vendor sees orders for their shop
            (vendor_owner_id::TEXT = p_user_id) 
            OR
            -- 3. Any Delivery Rider sees their assigned OR nearby unassigned orders
            (p_role = 'delivery' AND (rider_id::TEXT = p_user_id OR (rider_id IS NULL AND status IN ('PLACED', 'ACCEPTED', 'READY_FOR_PICKUP'))))
        )
        ORDER BY created_at DESC 
        LIMIT 30
    ) o;

    RETURN jsonb_build_object(
        'profile', COALESCE(v_profile, '{}'::jsonb),
        'orders', COALESCE(v_orders, '[]'::jsonb),
        'wallet', COALESCE(v_wallet, '{"balance": 0}'::jsonb),
        'server_time', NOW()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. REAL-TIME ARMAGEDDON (Enable for EVERY table used in lifecycle)
ALTER TABLE public.orders REPLICA IDENTITY FULL;
ALTER TABLE public.vendors REPLICA IDENTITY FULL;
ALTER TABLE public.delivery_riders REPLICA IDENTITY FULL;
ALTER TABLE public.customer_profiles REPLICA IDENTITY FULL;
ALTER TABLE public.wallets REPLICA IDENTITY FULL;
ALTER TABLE public.notifications REPLICA IDENTITY FULL;

DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

-- 5. SANITIZE & HARMONIZE ALL STATUSES
UPDATE public.orders SET status = 'PLACED' WHERE status IS NULL OR status = '';
UPDATE public.orders SET status = UPPER(status);
UPDATE public.orders SET payment_status = 'PENDING' WHERE payment_status IS NULL;
UPDATE public.orders SET payment_status = UPPER(payment_status);

COMMIT;
NOTIFY pgrst, 'reload schema';
