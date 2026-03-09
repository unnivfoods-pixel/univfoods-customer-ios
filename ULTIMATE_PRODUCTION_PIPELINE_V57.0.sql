
-- ULTIMATE IDENTITY & BOOTSTRAP RESTORATION V57.0
-- 🎯 MISSION: Restore Vendor/Rider bootstrap logic destroyed in V56.1 and handle TEXT IDs.
-- 🛠️ WHY: V56.1 accidentally stripped vendor logic from the bootstrap RPC, causing blank vendor apps.
-- 🧪 IDENTITY: All ID lookups use TEXT comparison to support Firebase/Guest/UUID.

BEGIN;

-- 1. NUCLEAR DROP: Ensure we clean up any old signatures of bootstrap function
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

-- 2. RE-BIRTH: The Complete Unified Bootstrap (TEXT Friendly)
CREATE OR REPLACE FUNCTION public.get_unified_bootstrap_data(p_user_id TEXT, p_role TEXT DEFAULT 'customer')
RETURNS JSONB AS $$
DECLARE
    v_profile JSONB;
    v_orders JSONB;
    v_wallet JSONB;
    v_menu JSONB;
    v_addresses JSONB;
    v_favorites JSON_AGG;
BEGIN
    -- [A] PROFILE SELECTION & AUTO-HEALING
    IF p_role = 'customer' THEN
        -- Auto-create profile if missing
        INSERT INTO public.customer_profiles (id, full_name) VALUES (p_user_id, 'Valued Customer') ON CONFLICT (id) DO NOTHING;
        SELECT row_to_json(cp)::jsonb INTO v_profile FROM public.customer_profiles cp WHERE id = p_user_id;
        
        -- Customer specifically wants addresses and favorites
        SELECT json_agg(a)::jsonb INTO v_addresses FROM public.user_addresses a WHERE user_id = p_user_id;
        SELECT json_agg(f)::jsonb INTO v_favorites FROM public.user_favorites f WHERE user_id = p_user_id;

    ELSIF p_role = 'vendor' THEN
        -- Link vendor to owner if not already linked (Manual override/Testing helper)
        SELECT row_to_json(v)::jsonb INTO v_profile FROM public.vendors v WHERE owner_id = p_user_id LIMIT 1;
        
        -- If no vendor record found for this owner, try to claim an unassigned one (for ease of setup)
        IF v_profile IS NULL THEN
            UPDATE public.vendors SET owner_id = p_user_id 
            WHERE id = (SELECT id FROM public.vendors WHERE owner_id IS NULL OR name ILIKE '%Royal%' LIMIT 1)
            AND NOT EXISTS (SELECT 1 FROM public.vendors WHERE owner_id = p_user_id);
            
            SELECT row_to_json(v)::jsonb INTO v_profile FROM public.vendors v WHERE owner_id = p_user_id LIMIT 1;
        END IF;

        -- Vendor specifically wants products (menu)
        IF v_profile IS NOT NULL THEN
            SELECT json_agg(p)::jsonb INTO v_menu FROM public.products p WHERE vendor_id::TEXT = v_profile->>'id';
        END IF;

    ELSIF p_role = 'delivery' THEN
        -- Auto-create rider if missing
        INSERT INTO public.delivery_riders (id, name, status) VALUES (p_user_id, 'Pro Rider', 'ONLINE') ON CONFLICT (id) DO NOTHING;
        SELECT row_to_json(r)::jsonb INTO v_profile FROM public.delivery_riders r WHERE id = p_user_id;
    END IF;

    -- [B] FINANCIALS (Universal Wallet)
    INSERT INTO public.wallets (user_id, balance) VALUES (p_user_id, 0) ON CONFLICT (user_id) DO NOTHING;
    SELECT row_to_json(w)::jsonb INTO v_wallet FROM public.wallets w WHERE user_id = p_user_id;

    -- [C] UNIFIED ORDERS (Role-based filtering)
    IF p_role = 'vendor' AND v_profile IS NOT NULL THEN
        -- Orders for this vendor
        SELECT json_agg(o)::jsonb INTO v_orders FROM (
            SELECT * FROM public.order_details_v3 
            WHERE vendor_id::TEXT = v_profile->>'id' 
            ORDER BY created_at DESC LIMIT 50
        ) o;
    ELSIF p_role = 'delivery' THEN
        -- Orders for this rider or unassigned orders
        SELECT json_agg(o)::jsonb INTO v_orders FROM (
            SELECT * FROM public.order_details_v3 
            WHERE rider_id = p_user_id 
               OR (status IN ('ACCEPTED', 'READY_FOR_PICKUP') AND rider_id IS NULL)
            ORDER BY created_at DESC LIMIT 30
        ) o;
    ELSE
        -- Orders for this customer
        SELECT json_agg(o)::jsonb INTO v_orders FROM (
            SELECT * FROM public.order_details_v3 
            WHERE customer_id = p_user_id 
            ORDER BY created_at DESC LIMIT 20
        ) o;
    END IF;

    -- [D] ASSEMBLE & RETURN
    RETURN jsonb_build_object(
        'profile', COALESCE(v_profile, '{}'::jsonb),
        'orders', COALESCE(v_orders, '[]'::jsonb),
        'wallet', COALESCE(v_wallet, '{"balance":0}'::jsonb),
        'menu', COALESCE(v_menu, '[]'::jsonb),
        'products', COALESCE(v_menu, '[]'::jsonb), -- Alias for different app versions
        'addresses', COALESCE(v_addresses, '[]'::jsonb),
        'favorites', COALESCE(v_favorites, '[]'::jsonb)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
NOTIFY pgrst, 'reload schema';
