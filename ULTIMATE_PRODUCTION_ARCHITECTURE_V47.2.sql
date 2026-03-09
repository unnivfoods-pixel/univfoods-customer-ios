-- 🛰️ THE ULTIMATE PRODUCTION ARCHITECTURE V47.2
-- 🎯 MISSION: Fix "customer_name" collision & Harden Schema.
-- 🛠️ FIX: Explicit column selection in View to avoid 'customer_name' collision from legacy Table columns.

BEGIN;

-- 1. CLEAN SLATE
DROP VIEW IF EXISTS public.order_details_v3 CASCADE;

-- 2. SCHEMA HARDENING (Ensure standard naming)
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS vendor_lat DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS vendor_lng DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS customer_lat DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS customer_lng DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS payment_webhook_id TEXT,
ADD COLUMN IF NOT EXISTS refund_status TEXT DEFAULT 'NONE';

-- High-Frequency GPS Table
CREATE TABLE IF NOT EXISTS public.order_live_tracking (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES public.orders(id) ON DELETE CASCADE,
    rider_id UUID REFERENCES public.delivery_riders(id),
    rider_lat DOUBLE PRECISION NOT NULL,
    rider_lng DOUBLE PRECISION NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 3. THE "TRUTH" VIEW (Explicit Selection to avoid collisions)
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
    COALESCE(o.delivery_lng, o.delivery_long) as delivery_lng,
    o.vendor_lat, 
    o.vendor_lng, 
    o.customer_lat, 
    o.customer_lng,
    o.payment_type, 
    o.payment_status,
    o.rider_id,
    v.name as vendor_name, 
    v.address as vendor_address, 
    v.owner_id as vendor_owner_id,
    cp.full_name as customer_name, 
    cp.phone as customer_phone,
    dr.name as rider_name, 
    dr.phone as rider_phone, 
    dr.rating as rider_rating,
    CASE 
        WHEN o.status = 'PAYMENT_PENDING' THEN 'Waiting for Payment'
        WHEN o.status = 'PLACED' THEN 'New Order'
        WHEN o.status = 'ACCEPTED' THEN 'Preparing'
        WHEN o.status = 'READY_FOR_PICKUP' THEN 'Ready for Pickup'
        WHEN o.status = 'RIDER_ASSIGNED' THEN 'Rider Coming'
        WHEN o.status = 'PICKED_UP' THEN 'Rider is Coming to You'
        WHEN o.status = 'ON_THE_WAY' THEN 'Out for Delivery'
        WHEN o.status = 'DELIVERED' THEN 'Delivered'
        WHEN o.status = 'CANCELLED' THEN 'Cancelled'
        ELSE UPPER(o.status)
    END as status_display
FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id = v.id
LEFT JOIN public.customer_profiles cp ON o.customer_id = cp.id
LEFT JOIN public.delivery_riders dr ON (o.rider_id::text = dr.id::text);

-- 4. BOOTSTRAP ENGINE (Updated to use new view)
CREATE OR REPLACE FUNCTION public.get_unified_bootstrap_data(p_user_id TEXT, p_role TEXT DEFAULT 'customer')
RETURNS JSONB AS $$
DECLARE
    v_profile JSONB;
    v_orders JSONB;
    v_wallet JSONB;
    v_menu JSONB;
BEGIN
    -- [A] Identity Linkage
    IF p_role = 'customer' THEN
        INSERT INTO public.customer_profiles (id, full_name) VALUES (p_user_id::UUID, 'Valued Customer') ON CONFLICT (id) DO NOTHING;
        SELECT row_to_json(p)::jsonb INTO v_profile FROM public.customer_profiles p WHERE id::TEXT = p_user_id;
    ELSIF p_role = 'vendor' THEN
        SELECT row_to_json(v)::jsonb INTO v_profile FROM public.vendors v WHERE owner_id::TEXT = p_user_id LIMIT 1;
        IF v_profile IS NULL THEN
            UPDATE public.vendors SET owner_id = p_user_id::UUID WHERE id = (SELECT id FROM public.vendors WHERE owner_id IS NULL OR name ILIKE '%Royal%' LIMIT 1);
            SELECT row_to_json(v)::jsonb INTO v_profile FROM public.vendors v WHERE owner_id::TEXT = p_user_id LIMIT 1;
        END IF;
    ELSIF p_role = 'delivery' THEN
        INSERT INTO public.delivery_riders (id, name, status) VALUES (p_user_id::UUID, 'Pro Rider', 'ONLINE') ON CONFLICT (id) DO NOTHING;
        SELECT row_to_json(r)::jsonb INTO v_profile FROM public.delivery_riders r WHERE id::TEXT = p_user_id;
    END IF;

    -- [B] Financials
    INSERT INTO public.wallets (user_id, balance) VALUES (p_user_id::UUID, 0) ON CONFLICT (user_id) DO NOTHING;
    SELECT row_to_json(w)::jsonb INTO v_wallet FROM public.wallets w WHERE user_id::TEXT = p_user_id;

    -- [C] Unified Orders
    SELECT json_agg(o)::jsonb INTO v_orders FROM (
        SELECT * FROM public.order_details_v3 
        WHERE customer_id::TEXT = p_user_id 
           OR vendor_owner_id::TEXT = p_user_id 
           OR (p_role = 'delivery' AND (rider_id::TEXT = p_user_id OR status = 'ACCEPTED' OR status = 'PLACED'))
        ORDER BY created_at DESC LIMIT 20
    ) o;

    -- [D] Menu (Vendor Only)
    IF p_role = 'vendor' AND v_profile IS NOT NULL THEN
        SELECT json_agg(p)::jsonb INTO v_menu FROM public.products p WHERE vendor_id = (v_profile->>'id')::UUID;
    END IF;

    RETURN jsonb_build_object(
        'profile', COALESCE(v_profile, '{}'::jsonb),
        'orders', COALESCE(v_orders, '[]'::jsonb),
        'wallet', COALESCE(v_wallet, '{"balance":0}'::jsonb),
        'menu', COALESCE(v_menu, '[]'::jsonb)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. REALTIME ACTIVATION
ALTER TABLE public.orders REPLICA IDENTITY FULL;
ALTER TABLE public.order_live_tracking REPLICA IDENTITY FULL;
ALTER TABLE public.vendors REPLICA IDENTITY FULL;
ALTER TABLE public.delivery_riders REPLICA IDENTITY FULL;

DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

COMMIT;
NOTIFY pgrst, 'reload schema';
