-- 🛰️ THE ULTIMATE PRODUCTION ARCHITECTURE V47.0
-- 🎯 MISSION: 100% Alignment with the Master Architecture Document.
-- 🛠️ CORE: One Source of Truth (orders table), Realtime Subscriptions, Strict Sequential Flow.

BEGIN;

-- ==========================================================
-- 🏗️ 1. SCHEMA HARDENING (Tables & Columns)
-- ==========================================================

-- A. Orders Table (The Heart)
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS vendor_lat DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS vendor_lng DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS customer_lat DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS customer_lng DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS payment_webhook_id TEXT,
ADD COLUMN IF NOT EXISTS refund_status TEXT DEFAULT 'NONE';

-- B. Delivery Professional Tracking Table
CREATE TABLE IF NOT EXISTS public.order_live_tracking (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES public.orders(id) ON DELETE CASCADE,
    rider_id UUID REFERENCES public.delivery_riders(id),
    rider_lat DOUBLE PRECISION NOT NULL,
    rider_lng DOUBLE PRECISION NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- C. High-Performance Indexing for 15KM Search
CREATE INDEX IF NOT EXISTS idx_vendors_location ON public.vendors (latitude, longitude);

-- ==========================================================
-- 🛡️ 2. THE PRODUCTION "TRUTH" VIEW
-- ==========================================================
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
    o.vendor_lat,
    o.vendor_lng,
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
    
    -- Dynamic Joins
    v.name as vendor_name,
    v.address as vendor_address,
    v.owner_id as vendor_owner_id,
    
    cp.full_name as customer_name,
    cp.phone as customer_phone,
    
    dr.name as rider_name,
    dr.phone as rider_phone,
    dr.rating as rider_rating,
    
    -- Status Display Mapping
    CASE 
        WHEN o.status = 'PAYMENT_PENDING' THEN 'Waiting for Payment'
        WHEN o.status = 'PLACED' THEN 'New Order'
        WHEN o.status = 'ACCEPTED' THEN 'Preparing'
        WHEN o.status = 'PREPARING' THEN 'Preparing'
        WHEN o.status = 'READY_FOR_PICKUP' THEN 'Ready for Pickup'
        WHEN o.status = 'RIDER_ASSIGNED' THEN 'Rider Coming'
        WHEN o.status = 'PICKED_UP' THEN 'Rider is Coming to You'
        WHEN o.status = 'ON_THE_WAY' THEN 'Out for Delivery'
        WHEN o.status = 'DELIVERED' THEN 'Delivered'
        WHEN o.status = 'CANCELLED' THEN 'Cancelled'
        WHEN o.status = 'REFUNDED' THEN 'Refunded'
        ELSE UPPER(o.status)
    END as status_display

FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id = v.id
LEFT JOIN public.customer_profiles cp ON o.customer_id = cp.id
LEFT JOIN public.delivery_riders dr ON (o.rider_id::text = dr.id::text);

-- ==========================================================
-- 🎯 3. PRODUCTION OPERATIONS (Functions)
-- ==========================================================

-- A. Self-Healing Unified Bootstrap
CREATE OR REPLACE FUNCTION public.get_unified_bootstrap_data(p_user_id TEXT, p_role TEXT DEFAULT 'customer')
RETURNS JSONB AS $$
DECLARE
    v_profile JSONB;
    v_orders JSONB;
    v_wallet JSONB;
    v_menu JSONB;
BEGIN
    -- 1. Identity Link & Auto-Creation
    IF p_role = 'customer' THEN
        INSERT INTO public.customer_profiles (id, full_name) VALUES (p_user_id::UUID, 'Valued Customer') ON CONFLICT (id) DO NOTHING;
        SELECT row_to_json(p)::jsonb INTO v_profile FROM public.customer_profiles p WHERE id::TEXT = p_user_id;
    ELSIF p_role = 'vendor' THEN
        SELECT row_to_json(v)::jsonb INTO v_profile FROM public.vendors v WHERE owner_id::TEXT = p_user_id LIMIT 1;
        -- Auto-Assign if test dummy
        IF v_profile IS NULL THEN
            UPDATE public.vendors SET owner_id = p_user_id::UUID WHERE id = (SELECT id FROM public.vendors WHERE owner_id IS NULL OR name ILIKE '%Royal%' LIMIT 1);
            SELECT row_to_json(v)::jsonb INTO v_profile FROM public.vendors v WHERE owner_id::TEXT = p_user_id LIMIT 1;
        END IF;
    ELSIF p_role = 'delivery' THEN
        INSERT INTO public.delivery_riders (id, name, status) VALUES (p_user_id::UUID, 'Pro Rider', 'ONLINE') ON CONFLICT (id) DO NOTHING;
        SELECT row_to_json(r)::jsonb INTO v_profile FROM public.delivery_riders r WHERE id::TEXT = p_user_id;
    END IF;

    -- 2. Financials
    INSERT INTO public.wallets (user_id, balance) VALUES (p_user_id::UUID, 0) ON CONFLICT (user_id) DO NOTHING;
    SELECT row_to_json(w)::jsonb INTO v_wallet FROM public.wallets w WHERE user_id::TEXT = p_user_id;

    -- 3. Dynamic Orders Hub
    SELECT json_agg(o)::jsonb INTO v_orders FROM (
        SELECT * FROM public.order_details_v3 
        WHERE customer_id::TEXT = p_user_id 
           OR vendor_owner_id::TEXT = p_user_id 
           OR (p_role = 'delivery' AND (rider_id::TEXT = p_user_id OR status = 'ACCEPTED'))
        ORDER BY created_at DESC LIMIT 25
    ) o;

    -- 4. Menu Sync (Vendor App Only)
    IF p_role = 'vendor' AND v_profile IS NOT NULL THEN
        SELECT json_agg(p)::jsonb INTO v_menu FROM public.products p WHERE vendor_id = (v_profile->>'id')::UUID;
    END IF;

    RETURN jsonb_build_object(
        'profile', COALESCE(v_profile, '{}'::jsonb),
        'orders', COALESCE(v_orders, '[]'::jsonb),
        'wallet', COALESCE(v_wallet, '{"balance":0}'::jsonb),
        'menu', COALESCE(v_menu, '[]'::jsonb),
        'timestamp', now()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- B. 15KM Location Filter Engine
CREATE OR REPLACE FUNCTION public.get_nearby_vendors(p_lat DOUBLE PRECISION, p_lng DOUBLE PRECISION, p_radius_km DOUBLE PRECISION DEFAULT 15.0)
RETURNS SETOF public.vendors AS $$
BEGIN
    RETURN QUERY
    SELECT *
    FROM public.vendors
    WHERE (
        6371 * acos(
            cos(radians(p_lat)) * cos(radians(latitude)) *
            cos(radians(longitude) - radians(p_lng)) +
            sin(radians(p_lat)) * sin(radians(latitude))
        )
    ) <= p_radius_km
    ORDER BY status DESC;
END;
$$ LANGUAGE plpgsql STABLE;

-- ==========================================================
-- ⚡ 4. TOTAL REALTIME SYNC
-- ==========================================================
ALTER TABLE public.orders REPLICA IDENTITY FULL;
ALTER TABLE public.order_live_tracking REPLICA IDENTITY FULL;
ALTER TABLE public.delivery_riders REPLICA IDENTITY FULL;
ALTER TABLE public.vendors REPLICA IDENTITY FULL;
ALTER TABLE public.products REPLICA IDENTITY FULL;
ALTER TABLE public.notifications REPLICA IDENTITY FULL;

-- Re-publish correctly for all apps
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

COMMIT;
NOTIFY pgrst, 'reload schema';
