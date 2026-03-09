-- 🏆 NUCLEAR DATABASE ARCHITECTURE (V15)
-- 🧠 THE MASTER TRUTH PROTOCOL
-- Purpose: Implement strict permanent storage and real-time sync for all core entities.

BEGIN;

-- ==========================================================
-- 👤 1. UNIFIED USERS & PROFILE ENHANCEMENT
-- ==========================================================
-- Ensure customer_profiles acts as the Master Users table
ALTER TABLE public.customer_profiles ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'customer';
ALTER TABLE public.customer_profiles ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;
ALTER TABLE public.customer_profiles ADD COLUMN IF NOT EXISTS last_login TIMESTAMPTZ;
ALTER TABLE public.customer_profiles ADD COLUMN IF NOT EXISTS profile_image TEXT;

-- ==========================================================
-- 📦 2. ORDER ITEMS (Permanent Child Storage)
-- ==========================================================
CREATE TABLE IF NOT EXISTS public.order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id UUID, -- References products(id) if exists
    name TEXT,
    quantity INTEGER NOT NULL,
    price DOUBLE PRECISION NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Fail-safe: Enable Realtime on child tables
ALTER TABLE public.order_items REPLICA IDENTITY FULL;

-- ==========================================================
-- 💰 3. PAYMENTS & REFUNDS (Permanent Financial Records)
-- ==========================================================
CREATE TABLE IF NOT EXISTS public.payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES public.orders(id),
    user_id TEXT, -- Linked to profile.id
    payment_method TEXT,
    transaction_id TEXT,
    amount DOUBLE PRECISION,
    status TEXT DEFAULT 'PENDING',
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.refunds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES public.orders(id),
    user_id TEXT,
    refund_reason TEXT,
    refund_status TEXT DEFAULT 'PENDING',
    refund_amount DOUBLE PRECISION,
    processed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.payments REPLICA IDENTITY FULL;
ALTER TABLE public.refunds REPLICA IDENTITY FULL;

-- ==========================================================
-- 🏠 4. ADDRESS SYNC ENHANCEMENT
-- ==========================================================
-- Ensure user_addresses has all requested fields
DO $$ 
BEGIN
    ALTER TABLE public.user_addresses ADD COLUMN IF NOT EXISTS address_line TEXT;
    ALTER TABLE public.user_addresses ADD COLUMN IF NOT EXISTS label TEXT;
    ALTER TABLE public.user_addresses ADD COLUMN IF NOT EXISTS phone TEXT;
    ALTER TABLE public.user_addresses ADD COLUMN IF NOT EXISTS pincode TEXT;
    ALTER TABLE public.user_addresses ADD COLUMN IF NOT EXISTS city TEXT;
    ALTER TABLE public.user_addresses ADD COLUMN IF NOT EXISTS is_default BOOLEAN DEFAULT FALSE;
    -- Alias full_address to address_line if both exist (Migration logic)
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_addresses' AND column_name='full_address') THEN
        UPDATE public.user_addresses SET address_line = full_address WHERE address_line IS NULL;
    END IF;
END $$;

-- ==========================================================
-- 🔄 5. MASTER BOOTSTRAP UPGRADE (Unified Data Fetch)
-- ==========================================================
CREATE OR REPLACE FUNCTION public.get_unified_bootstrap_data(p_user_id TEXT, p_role TEXT DEFAULT 'customer')
RETURNS JSON AS $$
DECLARE
    v_profile JSON;
    v_orders JSON;
    v_addresses JSON;
    v_payments JSON;
    v_refunds JSON;
    v_wallet JSON;
    v_notifications JSON;
    v_vendor_ids UUID[];
BEGIN
    -- 1. Profile & Branch logic
    IF p_role = 'vendor' THEN
        SELECT array_agg(id) INTO v_vendor_ids FROM public.vendors WHERE owner_id = p_user_id;
        SELECT row_to_json(v) INTO v_profile FROM public.vendors WHERE id = ANY(v_vendor_ids) LIMIT 1;
        SELECT json_agg(o) INTO v_orders FROM public.order_details_v3 o WHERE o.vendor_id = ANY(v_vendor_ids) ORDER BY o.created_at DESC;
    ELSIF p_role = 'delivery' THEN
        SELECT row_to_json(r) INTO v_profile FROM public.delivery_riders r WHERE r.id = p_user_id;
        SELECT json_agg(o) INTO v_orders FROM public.order_details_v3 o WHERE o.rider_id = p_user_id ORDER BY o.created_at DESC;
    ELSE -- 'customer'
        SELECT row_to_json(p) INTO v_profile FROM public.customer_profiles p WHERE p.id = p_user_id;
        SELECT json_agg(o) INTO v_orders FROM public.order_details_v3 o WHERE o.customer_id = p_user_id ORDER BY o.created_at DESC;
        SELECT json_agg(a) INTO v_addresses FROM public.user_addresses a WHERE a.user_id = p_user_id;
    END IF;

    -- 2. Master History (Financials)
    SELECT json_agg(pm) INTO v_payments FROM public.payments pm WHERE pm.user_id = p_user_id ORDER BY pm.created_at DESC;
    SELECT json_agg(rf) INTO v_refunds FROM public.refunds rf WHERE rf.user_id = p_user_id ORDER BY rf.created_at DESC;

    -- 3. Common Data
    SELECT row_to_json(w) INTO v_wallet FROM public.wallets w WHERE w.user_id = p_user_id;
    SELECT json_agg(n) INTO v_notifications FROM public.notifications n WHERE n.user_id = p_user_id AND n.is_read = FALSE;

    RETURN json_build_object(
        'profile', COALESCE(v_profile, '{}'::json),
        'orders', COALESCE(v_orders, '[]'::json),
        'addresses', COALESCE(v_addresses, '[]'::json),
        'payments', COALESCE(v_payments, '[]'::json),
        'refunds', COALESCE(v_refunds, '[]'::json),
        'wallet', COALESCE(v_wallet, '{"balance": 0}'::json),
        'notifications', COALESCE(v_notifications, '[]'::json)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==========================================================
-- ⚡ 6. MASTER REALTIME PUBLICATION (Include All)
-- ==========================================================
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

COMMIT;
