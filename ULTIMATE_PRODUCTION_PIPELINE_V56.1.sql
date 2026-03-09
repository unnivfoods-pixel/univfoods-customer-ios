
-- ULTIMATE PRODUCTION PIPELINE V56.1 (FUNCTION ERADICATION & REBIRTH)
-- 🎯 MISSION: Fix "Multiple Choices" (PGRST203) once and for all.
-- 🛠️ WHY: Manually dropping signatures is failing because there are hidden variations.
-- 🧨 NUCLEAR OPTION: This script finds and deletes EVERY function named 'place_order_v6' first.

BEGIN;

-- 1. NUCLEAR DROP: Delete all functions named 'place_order_v6' regardless of arguments
DO $$ 
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT n.nspname as schema, p.proname as name, pg_get_function_identity_arguments(p.oid) as args
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE p.proname = 'place_order_v6'
          AND n.nspname = 'public'
    ) LOOP
        EXECUTE 'DROP FUNCTION ' || quote_ident(r.schema) || '.' || quote_ident(r.name) || '(' || r.args || ')';
    END LOOP;
END $$;

-- 2. RE-BIRTH: Create the ONE AND ONLY TEXT-based version
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
    -- Standard status logic (COD vs Paid)
    v_initial_status := CASE 
        WHEN p_payment_method IN ('UPI', 'CARD') THEN 'PAYMENT_PENDING' 
        ELSE 'PLACED' 
    END;

    INSERT INTO public.orders (
        customer_id, 
        vendor_id, 
        items, 
        total, 
        status, 
        payment_method, 
        payment_status, 
        address, 
        delivery_address,
        delivery_lat, 
        delivery_lng, 
        cooking_instructions, 
        delivery_address_id, 
        created_at
    ) VALUES (
        p_customer_id, 
        p_vendor_id, 
        p_items, 
        p_total, 
        v_initial_status,
        p_payment_method, 
        'PENDING', 
        p_address, 
        p_address,
        p_lat, 
        p_lng, 
        p_instructions, 
        p_address_id, 
        NOW()
    ) RETURNING id INTO v_order_id;

    RETURN v_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. CLEANUP OTHER POTENTIAL OVERLOADS (Safety)
DO $$ 
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT n.nspname as schema, p.proname as name, pg_get_function_identity_arguments(p.oid) as args
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE p.proname = 'get_unified_bootstrap_data'
          AND n.nspname = 'public'
    ) LOOP
        EXECUTE 'DROP FUNCTION ' || quote_ident(r.schema) || '.' || quote_ident(r.name) || '(' || r.args || ')';
    END LOOP;
END $$;

-- 4. RESTORE REQUIRED BOOTSTRAP (TEXT Version)
CREATE OR REPLACE FUNCTION public.get_unified_bootstrap_data(p_user_id TEXT, p_role TEXT DEFAULT 'customer')
RETURNS JSONB AS $$
DECLARE
    v_profile JSONB;
    v_orders JSONB;
    v_wallet JSONB;
BEGIN
    IF p_role = 'customer' THEN
        INSERT INTO public.customer_profiles (id, full_name) VALUES (p_user_id, 'Customer') ON CONFLICT (id) DO NOTHING;
        SELECT row_to_json(p)::jsonb INTO v_profile FROM public.customer_profiles p WHERE id = p_user_id;
    END IF;

    INSERT INTO public.wallets (user_id, balance) VALUES (p_user_id, 0) ON CONFLICT (user_id) DO NOTHING;
    SELECT row_to_json(w)::jsonb INTO v_wallet FROM public.wallets w WHERE user_id = p_user_id;

    SELECT json_agg(o)::jsonb INTO v_orders FROM (
        SELECT * FROM public.order_details_v3 WHERE customer_id = p_user_id ORDER BY created_at DESC LIMIT 50
    ) o;

    RETURN jsonb_build_object('profile', v_profile, 'orders', v_orders, 'wallet', v_wallet);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
NOTIFY pgrst, 'reload schema';
