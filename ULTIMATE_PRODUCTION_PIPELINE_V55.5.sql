
-- ULTIMATE PRODUCTION PIPELINE V55.5 (VIEW & BOOTSTRAP IDENTITY HEALING)
-- 🎯 MISSION: Fix "cannot alter type of a column used by a view".
-- 🛠️ WHY: order_details_v3 depends on customer_id. We must drop it first.

BEGIN;

-- 1. DROP DEPENDENT VIEWS & FUNCTIONS (CASCADE handles dependencies)
DROP VIEW IF EXISTS public.order_details_v3 CASCADE;

-- 2. DROP POLICIES (Unlocking columns)
DROP POLICY IF EXISTS "Users can view own orders" ON public.orders;
DROP POLICY IF EXISTS "Individuals can view their own profile" ON public.customer_profiles;
DROP POLICY IF EXISTS "Users can view own wallet" ON public.wallets;

-- 3. MIGRATE IDENTITY COLUMNS TO TEXT
-- This supports Firebase UIDs, Guest IDs, and standard UUIDs.
ALTER TABLE public.orders ALTER COLUMN customer_id TYPE TEXT;
ALTER TABLE public.customer_profiles ALTER COLUMN id TYPE TEXT;
ALTER TABLE public.wallets ALTER COLUMN user_id TYPE TEXT;

-- 4. RECREATE THE "TRUTH" VIEW (order_details_v3)
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
LEFT JOIN public.customer_profiles cp ON o.customer_id::TEXT = cp.id::TEXT
LEFT JOIN public.delivery_riders dr ON (o.rider_id::TEXT = dr.id::TEXT);

-- 5. RECREATE POLICIES (TEXT Compatible)
CREATE POLICY "Users can view own orders" ON public.orders
    FOR SELECT USING (auth.uid()::TEXT = customer_id);

CREATE POLICY "Individuals can view their own profile" ON public.customer_profiles
    FOR SELECT USING (auth.uid()::TEXT = id);

CREATE POLICY "Users can view own wallet" ON public.wallets
    FOR SELECT USING (auth.uid()::TEXT = user_id);

-- 6. UPGRADE BOOTSTRAP ENGINE (Removing restrictive UUID casts)
CREATE OR REPLACE FUNCTION public.get_unified_bootstrap_data(p_user_id TEXT, p_role TEXT DEFAULT 'customer')
RETURNS JSONB AS $$
DECLARE
    v_profile JSONB;
    v_orders JSONB;
    v_wallet JSONB;
    v_menu JSONB;
    v_vendor_id UUID;
BEGIN
    -- [A] Identity Linkage (No forced UUID cast)
    IF p_role = 'customer' THEN
        INSERT INTO public.customer_profiles (id, full_name, updated_at) 
        VALUES (p_user_id, 'Customer', NOW()) 
        ON CONFLICT (id) DO UPDATE SET updated_at = NOW();
        
        SELECT row_to_json(p)::jsonb INTO v_profile FROM public.customer_profiles p WHERE id = p_user_id;
    ELSIF p_role = 'vendor' THEN
        SELECT id INTO v_vendor_id FROM public.vendors WHERE owner_id::TEXT = p_user_id LIMIT 1;
        SELECT row_to_json(v)::jsonb INTO v_profile FROM public.vendors v WHERE id = v_vendor_id;
    ELSIF p_role = 'delivery' THEN
        SELECT row_to_json(r)::jsonb INTO v_profile FROM public.delivery_riders r WHERE id::TEXT = p_user_id;
    END IF;

    -- [B] Financials
    INSERT INTO public.wallets (user_id, balance) VALUES (p_user_id, 0) ON CONFLICT (user_id) DO NOTHING;
    SELECT row_to_json(w)::jsonb INTO v_wallet FROM public.wallets w WHERE user_id = p_user_id;

    -- [C] Unified Orders (Using healed view)
    SELECT json_agg(o)::jsonb INTO v_orders FROM (
        SELECT * FROM public.order_details_v3 
        WHERE customer_id = p_user_id 
           OR vendor_owner_id::TEXT = p_user_id 
           OR (p_role = 'delivery' AND (rider_id::TEXT = p_user_id OR status IN ('PLACED', 'ACCEPTED')))
        ORDER BY created_at DESC LIMIT 50
    ) o;

    RETURN jsonb_build_object(
        'profile', COALESCE(v_profile, '{}'::jsonb),
        'orders', COALESCE(v_orders, '[]'::jsonb),
        'wallet', COALESCE(v_wallet, '{"balance":0}'::jsonb)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. RESTORE ORDER PLACEMENT (TEXT Compatible)
CREATE OR REPLACE FUNCTION public.place_order_v6(
    p_customer_id TEXT,
    p_vendor_id UUID,
    p_items JSONB,
    p_total DECIMAL,
    p_address TEXT,
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION,
    p_payment_method TEXT,
    p_instructions TEXT DEFAULT '',
    p_address_id TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_order_id UUID;
    v_initial_status TEXT;
BEGIN
    v_initial_status := CASE WHEN p_payment_method IN ('UPI', 'CARD') THEN 'PAYMENT_PENDING' ELSE 'PLACED' END;

    INSERT INTO public.orders (
        customer_id, vendor_id, items, total, status, 
        payment_method, payment_status, address, delivery_address,
        delivery_lat, delivery_lng, cooking_instructions, delivery_address_id, created_at
    ) VALUES (
        p_customer_id, p_vendor_id, p_items, p_total, v_initial_status,
        p_payment_method, 'PENDING', p_address, p_address,
        p_lat, p_lng, p_instructions, p_address_id, NOW()
    ) RETURNING id INTO v_order_id;

    RETURN v_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
NOTIFY pgrst, 'reload schema';
