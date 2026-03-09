
-- NUCLEAR IDENTITY & LOGISTICS RESTORATION V57.4
-- 🎯 MISSION: Fix Real-time Orders, History, Earnings, and Vendor Identity Sync.
-- 🛠️ WHY: Vendor App was in a "Quiet on front" state due to ID mismatches and missing views.
-- 🧪 IDENTITY: Pure TEXT-based unlock with hardened Logistics Views.

BEGIN;

-- 1. DROP DEPENDENT VIEWS (Clean Slate for Logistics)
DROP VIEW IF EXISTS public.order_details_v3 CASCADE;
DROP VIEW IF EXISTS public.vendor_earnings_stats CASCADE;

-- 2. ENSURE REPLICA IDENTITY FULL (Critical for Real-time)
-- This forces Postgres to broadcast ALL columns on every change.
ALTER TABLE public.orders REPLICA IDENTITY FULL;
ALTER TABLE public.vendors REPLICA IDENTITY FULL;
ALTER TABLE public.products REPLICA IDENTITY FULL;
ALTER TABLE public.wallets REPLICA IDENTITY FULL;
ALTER TABLE public.delivery_riders REPLICA IDENTITY FULL;

-- 3. THE "TRUTH" LOGISTICS VIEW (Hardened)
CREATE OR REPLACE VIEW public.order_details_v3 AS
SELECT 
    o.id, 
    o.created_at, 
    o.customer_id, 
    o.vendor_id, 
    o.total, 
    o.status, 
    o.items,
    o.delivery_lat, 
    o.delivery_lng, 
    o.delivery_address, 
    o.delivery_address_id,
    o.rider_id, 
    o.payment_method as payment_type, 
    o.payment_status,
    o.cooking_instructions,
    v.name as vendor_name, 
    v.address as vendor_address, 
    v.owner_id as vendor_owner_id,
    cp.full_name as customer_name, 
    cp.phone as customer_phone,
    dr.name as rider_name, 
    dr.phone as rider_phone,
    CASE 
        WHEN o.status = 'PLACED' THEN 'New Order'
        WHEN o.status = 'ACCEPTED' THEN 'Preparing'
        WHEN o.status = 'READY_FOR_PICKUP' THEN 'Ready'
        WHEN o.status = 'DELIVERED' THEN 'Completed'
        WHEN o.status = 'CANCELLED' THEN 'Cancelled'
        ELSE UPPER(o.status)
    END as status_display
FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id = v.id
LEFT JOIN public.customer_profiles cp ON o.customer_id = cp.id
LEFT JOIN public.delivery_riders dr ON o.rider_id = dr.id;

-- 4. VENDOR EARNINGS VIEW
CREATE OR REPLACE VIEW public.vendor_earnings_stats AS
SELECT 
    vendor_id,
    COUNT(*) FILTER (WHERE status = 'PLACED') as pending_orders,
    SUM(total) FILTER (WHERE status = 'DELIVERED') as total_earnings,
    COUNT(*) FILTER (WHERE status = 'DELIVERED') as completed_orders
FROM public.orders
GROUP BY vendor_id;

-- 5. THE MASTER BOOTSTRAP (Unified, Multi-Role, TEXT-Native)
CREATE OR REPLACE FUNCTION public.get_unified_bootstrap_data(p_user_id TEXT, p_role TEXT DEFAULT 'customer')
RETURNS JSONB AS $$
DECLARE
    v_profile JSONB;
    v_orders JSONB;
    v_wallet JSONB;
    v_menu JSONB;
    v_stats JSONB;
BEGIN
    -- [A] FINANCIALS (Always Provisioned)
    INSERT INTO public.wallets (user_id, balance, role) 
    VALUES (p_user_id, 0, UPPER(p_role)) 
    ON CONFLICT (user_id) DO UPDATE SET role = UPPER(p_role);
    
    SELECT row_to_json(w)::jsonb INTO v_wallet FROM public.wallets w WHERE user_id = p_user_id;

    -- [B] ROLE SPECIFIC PROVISIONING
    IF p_role = 'vendor' THEN
        -- Setup helper: Auto-claim vendor if owner_id is null and user is vendor role
        UPDATE public.vendors SET owner_id = p_user_id 
        WHERE (owner_id IS NULL OR owner_id = '') 
        AND name ILIKE '%Royal%' 
        AND NOT EXISTS (SELECT 1 FROM public.vendors WHERE owner_id = p_user_id);

        SELECT row_to_json(v)::jsonb INTO v_profile FROM public.vendors v WHERE owner_id = p_user_id LIMIT 1;
        
        IF v_profile IS NOT NULL THEN
            -- Load Vendor Products (Menu)
            SELECT json_agg(p)::jsonb INTO v_menu FROM public.products p WHERE vendor_id::TEXT = v_profile->>'id';
            
            -- Load Vendor Orders (Full History)
            SELECT json_agg(o)::jsonb INTO v_orders FROM (
                SELECT * FROM public.order_details_v3 
                WHERE vendor_owner_id = p_user_id 
                ORDER BY created_at DESC LIMIT 100
            ) o;

            -- Load Stats
            SELECT row_to_json(s)::jsonb INTO v_stats FROM public.vendor_earnings_stats s WHERE vendor_id::TEXT = v_profile->>'id';
        END IF;

    ELSIF p_role = 'delivery' THEN
        -- Auto-provision rider profile
        INSERT INTO public.delivery_riders (id, name, status) VALUES (p_user_id, 'Pro Rider', 'ONLINE') ON CONFLICT (id) DO NOTHING;
        SELECT row_to_json(r)::jsonb INTO v_profile FROM public.delivery_riders r WHERE id = p_user_id;
        
        -- Load Rider Orders
        SELECT json_agg(o)::jsonb INTO v_orders FROM (
            SELECT * FROM public.order_details_v3 
            WHERE rider_id = p_user_id 
               OR (status IN ('ACCEPTED', 'READY_FOR_PICKUP') AND rider_id IS NULL)
            ORDER BY created_at DESC LIMIT 30
        ) o;

    ELSE -- Default: Customer
        -- Auto-provision customer profile
        INSERT INTO public.customer_profiles (id, full_name) VALUES (p_user_id, 'Valued Customer') ON CONFLICT (id) DO NOTHING;
        SELECT row_to_json(cp)::jsonb INTO v_profile FROM public.customer_profiles cp WHERE id = p_user_id;
        
        -- Load Customer Orders
        SELECT json_agg(o)::jsonb INTO v_orders FROM (
            SELECT * FROM public.order_details_v3 WHERE customer_id = p_user_id ORDER BY created_at DESC LIMIT 20
        ) o;
    END IF;

    -- [C] ASSEMBLE & RETURN
    RETURN jsonb_build_object(
        'profile', COALESCE(v_profile, '{}'::jsonb),
        'orders', COALESCE(v_orders, '[]'::jsonb),
        'wallet', COALESCE(v_wallet, '{"balance":0}'::jsonb),
        'menu', COALESCE(v_menu, '[]'::jsonb),
        'products', COALESCE(v_menu, '[]'::jsonb), -- Double key for safety
        'stats', COALESCE(v_stats, '{"total_earnings":0,"pending_orders":0}'::jsonb),
        'timestamp', NOW()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
NOTIFY pgrst, 'reload schema';
