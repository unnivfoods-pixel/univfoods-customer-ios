-- 🛰️ THE TOTAL REALTIME ARMAGEDDON V46.0
-- 🎯 MISSION: 100% Zero-Latency, Universal Identity, and View-Safety.
-- 🛠️ RULE: Any user who logs in MUST see a functional dashboard. No blank screens.

BEGIN;

-- 1. CLEANUP & VIEW SAFETY (Resetting for clean dynamic columns)
DROP VIEW IF EXISTS public.order_details_v3 CASCADE;
DROP FUNCTION IF EXISTS public.get_unified_bootstrap_data(TEXT, TEXT);

-- 2. UNIVERSAL DYNAMIC VIEW (The Single Truth)
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
    
    -- Dynamic Joins (Generic for any user)
    v.name as vendor_name,
    v.address as vendor_address,
    v.owner_id as vendor_owner_id,
    v.latitude as vendor_lat,
    v.longitude as vendor_lng,
    
    cp.full_name as customer_name,
    cp.phone as customer_phone,
    
    dr.name as rider_name,
    dr.phone as rider_phone,
    dr.current_lat as rider_live_lat,
    dr.current_lng as rider_live_lng,
    dr.heading as rider_heading,
    
    -- Universal UI Status Matrix
    CASE 
        WHEN o.status = 'PAYMENT_PENDING' THEN 'Waiting for Payment'
        WHEN o.status = 'PLACED' THEN 'New Order'
        WHEN o.status = 'ACCEPTED' THEN 'Vendor Accepted'
        WHEN o.status = 'PREPARING' THEN 'Preparing'
        WHEN o.status = 'READY_FOR_PICKUP' THEN 'Ready for Delivery'
        WHEN o.status = 'RIDER_ASSIGNED' THEN 'Rider Coming'
        WHEN o.status = 'PICKED_UP' THEN 'Picked Up'
        WHEN o.status = 'ON_THE_WAY' THEN 'On the Way'
        WHEN o.status = 'DELIVERED' THEN 'Delivered'
        WHEN o.status = 'CANCELLED' THEN 'Cancelled'
        ELSE UPPER(o.status)
    END as status_display

FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id = v.id
LEFT JOIN public.customer_profiles cp ON o.customer_id = cp.id
LEFT JOIN public.delivery_riders dr ON (o.rider_id::text = dr.id::text);

-- 3. THE MASTER BOOTSTRAP ENGINE (With Self-Healing Identity)
CREATE OR REPLACE FUNCTION public.get_unified_bootstrap_data(p_user_id TEXT, p_role TEXT DEFAULT 'customer')
RETURNS JSONB AS $$
DECLARE
    v_profile JSONB;
    v_orders JSONB;
    v_wallet JSONB;
    v_products JSONB;
    v_vendor_id UUID;
BEGIN
    -- [A] PROFILE & IDENTITY SELF-HEALING
    IF p_role = 'customer' THEN
        -- Auto-create customer profile if missing
        INSERT INTO public.customer_profiles (id, full_name, created_at)
        VALUES (p_user_id::UUID, 'New Customer', NOW())
        ON CONFLICT (id) DO NOTHING;
        
        SELECT row_to_json(p)::jsonb INTO v_profile FROM public.customer_profiles p WHERE id::TEXT = p_user_id;

    ELSIF p_role = 'vendor' THEN
        -- Link to vendor by owner_id
        SELECT row_to_json(v)::jsonb INTO v_profile FROM public.vendors v WHERE owner_id::TEXT = p_user_id LIMIT 1;
        
        -- Fallback: If no shop owned, use the Default Shop for testing
        IF v_profile IS NULL THEN
            UPDATE public.vendors 
            SET owner_id = p_user_id::UUID 
            WHERE id = (
                SELECT id FROM public.vendors 
                WHERE (owner_id IS NULL OR name ILIKE '%Royal%')
                LIMIT 1
            );
            
            SELECT row_to_json(v)::jsonb INTO v_profile FROM public.vendors v WHERE owner_id::TEXT = p_user_id LIMIT 1;
        END IF;

    ELSIF p_role = 'delivery' THEN
        -- Auto-create rider if missing
        INSERT INTO public.delivery_riders (id, name, status, created_at)
        VALUES (p_user_id::UUID, 'Active Rider', 'ONLINE', NOW())
        ON CONFLICT (id) DO NOTHING;
        
        SELECT row_to_json(r)::jsonb INTO v_profile FROM public.delivery_riders r WHERE id::TEXT = p_user_id;
    END IF;

    -- [B] WALLET SYNC
    INSERT INTO public.wallets (user_id, balance) 
    VALUES (p_user_id::UUID, 0) 
    ON CONFLICT (user_id) DO NOTHING;
    
    SELECT row_to_json(w)::jsonb INTO v_wallet FROM public.wallets w WHERE user_id::TEXT = p_user_id;

    -- [C] MENU SYNC (For Vendors)
    IF p_role = 'vendor' AND v_profile IS NOT NULL THEN
        SELECT json_agg(p)::jsonb INTO v_products 
        FROM public.products p 
        WHERE vendor_id = (v_profile->>'id')::UUID;
    END IF;

    -- [D] MASTER ORDER STREAM
    SELECT json_agg(o)::jsonb INTO v_orders 
    FROM (
        SELECT * FROM public.order_details_v3 
        WHERE (
            (customer_id::TEXT = p_user_id) 
            OR (vendor_owner_id::TEXT = p_user_id) 
            OR (p_role = 'delivery' AND (rider_id::TEXT = p_user_id OR (rider_id IS NULL AND status IN ('PLACED', 'ACCEPTED'))))
        )
        ORDER BY created_at DESC 
        LIMIT 50
    ) o;

    RETURN jsonb_build_object(
        'profile', COALESCE(v_profile, '{}'::jsonb),
        'orders', COALESCE(v_orders, '[]'::jsonb),
        'wallet', COALESCE(v_wallet, '{"balance":0}'::jsonb),
        'menu', COALESCE(v_products, '[]'::jsonb),
        'server_time', NOW()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. ENABLE REAL-TIME BROADCASTS (Arming the whole system)
ALTER TABLE public.orders REPLICA IDENTITY FULL;
ALTER TABLE public.vendors REPLICA IDENTITY FULL;
ALTER TABLE public.delivery_riders REPLICA IDENTITY FULL;
ALTER TABLE public.products REPLICA IDENTITY FULL;
ALTER TABLE public.wallets REPLICA IDENTITY FULL;
ALTER TABLE public.notifications REPLICA IDENTITY FULL;

-- Re-create Publication for ALL Tables
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

COMMIT;
NOTIFY pgrst, 'reload schema';
