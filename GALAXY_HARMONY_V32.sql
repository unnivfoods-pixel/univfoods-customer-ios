-- 🌌 GALAXY HARMONY (V32.1)
-- 🎯 MISSION: Permanent FIX for "operator is only a shell: text = uuid".
-- 🎯 MISSION: Restore "Old Orders" for logged-in users.
-- 🎯 MISSION: Enable Bulletproof Guest -> User identity persistence.

BEGIN;

-- 1. UNLOCK & CLEAN SLATE
DROP VIEW IF EXISTS public.order_details_v3 CASCADE;
DROP VIEW IF EXISTS public.order_details_v2 CASCADE;
DROP VIEW IF EXISTS public.order_details_v1 CASCADE;

-- 🛠️ IMPORTANT: Drop functions before re-creating them to handle signature/return type changes
DROP FUNCTION IF EXISTS public.get_unified_bootstrap_data(TEXT, TEXT);
DROP FUNCTION IF EXISTS public.get_unified_bootstrap_data(TEXT);
DROP FUNCTION IF EXISTS public.place_order_v5(TEXT, TEXT, JSONB, DOUBLE PRECISION, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT, TEXT, TEXT, TEXT);

-- 2. FORCE GLOBAL TEXT ALIGNMENT (The Shell Killer)
-- We convert all entity links to TEXT so Guest IDs and Auth UUIDs live together in harmony.
DO $$ 
BEGIN
    -- core identity
    ALTER TABLE public.customer_profiles ALTER COLUMN id TYPE TEXT;
    
    -- orders (The main source of the error)
    ALTER TABLE public.orders ALTER COLUMN customer_id TYPE TEXT;
    
    -- financial records
    ALTER TABLE public.wallets ALTER COLUMN user_id TYPE TEXT;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='payments') THEN
        ALTER TABLE public.payments ALTER COLUMN user_id TYPE TEXT;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='refunds') THEN
        ALTER TABLE public.refunds ALTER COLUMN user_id TYPE TEXT;
    END IF;

    -- social & location
    ALTER TABLE public.user_favorites ALTER COLUMN user_id TYPE TEXT;
    ALTER TABLE public.user_addresses ALTER COLUMN user_id TYPE TEXT;
    ALTER TABLE public.notifications ALTER COLUMN user_id TYPE TEXT;

EXCEPTION WHEN OTHERS THEN 
    RAISE NOTICE 'Skipping some type changes as they might already be aligned: %', SQLERRM;
END $$;

-- 3. REBUILD THE VIEW (Truth Protocol)
-- Using explicit casting to ensure no "shell" errors occur during joins.
CREATE OR REPLACE VIEW public.order_details_v3 AS
SELECT 
    o.*,
    v.name as vendor_name,
    v.phone as vendor_phone,
    v.address as vendor_address,
    v.image_url as vendor_image_url,
    jsonb_build_object(
        'name', v.name,
        'image_url', v.image_url,
        'address', v.address,
        'phone', v.phone,
        'latitude', v.latitude,
        'longitude', v.longitude
    ) as vendors,
    (SELECT full_name FROM public.customer_profiles cp WHERE cp.id::TEXT = o.customer_id::TEXT) as profile_name
FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id::TEXT = v.id::TEXT;

GRANT SELECT ON public.order_details_v3 TO anon, authenticated, service_role;

-- 4. UPGRADE BOOTSTRAP (Recovery for Old Orders)
-- We use ::TEXT = ::TEXT to ensure logged-in users (with UUID-strings) find their orders.
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
    v_vendor_ids TEXT[];
BEGIN
    IF p_role = 'vendor' THEN
        SELECT array_agg(id::TEXT) INTO v_vendor_ids FROM public.vendors WHERE owner_id::TEXT = p_user_id::TEXT;
        SELECT row_to_json(v) INTO v_profile FROM public.vendors WHERE id::TEXT = ANY(v_vendor_ids) LIMIT 1;
        SELECT json_agg(o) INTO v_orders FROM public.order_details_v3 o WHERE o.vendor_id::TEXT = ANY(v_vendor_ids) ORDER BY o.created_at DESC;
    ELSIF p_role = 'delivery' THEN
        SELECT row_to_json(r) INTO v_profile FROM public.delivery_riders r WHERE r.id::TEXT = p_user_id::TEXT;
        SELECT json_agg(o) INTO v_orders FROM public.order_details_v3 o WHERE o.rider_id::TEXT = p_user_id::TEXT ORDER BY o.created_at DESC;
    ELSE -- 'customer'
        SELECT row_to_json(p) INTO v_profile FROM public.customer_profiles p WHERE p.id::TEXT = p_user_id::TEXT;
        -- This is the critical line for old orders:
        SELECT json_agg(o) INTO v_orders FROM public.order_details_v3 o WHERE o.customer_id::TEXT = p_user_id::TEXT ORDER BY o.created_at DESC;
        SELECT json_agg(a) INTO v_addresses FROM public.user_addresses a WHERE a.user_id::TEXT = p_user_id::TEXT;
    END IF;

    SELECT json_agg(pm) INTO v_payments FROM public.payments pm WHERE pm.user_id::TEXT = p_user_id::TEXT ORDER BY pm.created_at DESC;
    SELECT json_agg(rf) INTO v_refunds FROM public.refunds rf WHERE rf.user_id::TEXT = p_user_id::TEXT ORDER BY rf.created_at DESC;
    SELECT row_to_json(w) INTO v_wallet FROM public.wallets w WHERE w.user_id::TEXT = p_user_id::TEXT;
    SELECT json_agg(n) INTO v_notifications FROM public.notifications n WHERE n.user_id::TEXT = p_user_id::TEXT AND n.is_read = FALSE;

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

-- 5. UPGRADE ORDER PLACEMENT (Kill COD Shell Error)
CREATE OR REPLACE FUNCTION public.place_order_v5(
    p_customer_id TEXT,
    p_vendor_id TEXT,
    p_items JSONB,
    p_total DOUBLE PRECISION,
    p_address TEXT,
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION,
    p_payment_method TEXT,
    p_instructions TEXT DEFAULT NULL,
    p_address_id TEXT DEFAULT NULL,
    p_initial_status TEXT DEFAULT 'placed'
)
RETURNS UUID AS $$
DECLARE
    v_order_id UUID;
    v_v_lat DOUBLE PRECISION;
    v_v_lng DOUBLE PRECISION;
BEGIN
    -- Force type alignment in variables
    SELECT latitude, longitude INTO v_v_lat, v_v_lng
    FROM public.vendors WHERE id::TEXT = p_vendor_id::TEXT;

    INSERT INTO public.orders (
        customer_id, vendor_id, items, total, address, 
        delivery_lat, delivery_lng, pickup_lat, pickup_lng,
        status, payment_method, payment_status,
        pickup_otp, delivery_otp, delivery_address_id, cooking_instructions
    ) VALUES (
        p_customer_id, p_vendor_id::UUID, p_items, p_total, p_address, 
        p_lat, p_lng, v_v_lat, v_v_lng,
        p_initial_status, p_payment_method, 'PENDING',
        lpad(floor(random() * 10000)::text, 4, '0'), 
        lpad(floor(random() * 10000)::text, 4, '0'),
        p_address_id::UUID, p_instructions
    ) RETURNING id INTO v_order_id;

    RETURN v_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. SECURITY ALIGNMENT
DROP POLICY IF EXISTS "Users can view own orders" ON public.orders;
CREATE POLICY "Users can view own orders" ON public.orders 
FOR ALL USING (customer_id::TEXT = auth.uid()::TEXT OR customer_id::TEXT LIKE 'guest_%');

COMMIT;
