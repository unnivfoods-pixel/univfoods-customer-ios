-- 👑 DATA PERSISTENCE & GUEST HEALING (V28.1)
-- Fixes: Disappearing Favorites, Broken Migration, and ID Type Mismatches.

BEGIN;

-- 1. HEAL USER_FAVORITES TABLE
-- We MUST drop the policy before altering the column type
DROP POLICY IF EXISTS "Users can manage own favorites" ON public.user_favorites;

-- Change user_id to TEXT to support Guest IDs (guest_123...)
ALTER TABLE public.user_favorites ALTER COLUMN user_id TYPE TEXT;

-- Recreate policy with TEXT compatibility
CREATE POLICY "Users can manage own favorites" 
ON public.user_favorites FOR ALL 
USING (
    user_id = auth.uid()::TEXT 
    OR user_id = '88888888-8888-8888-8888-888888888888' -- System Override ID
);

-- 2. UPGRADE MIGRATION ENGINE (V5 - Now including Favorites)
CREATE OR REPLACE FUNCTION public.migrate_guest_orders_v5(p_guest_id TEXT, p_auth_id TEXT)
RETURNS VOID AS $$
DECLARE
    v_guest_bal DOUBLE PRECISION;
    v_auth_bal DOUBLE PRECISION;
BEGIN
    -- A. MOVE ORDERS
    UPDATE public.orders SET customer_id = p_auth_id WHERE customer_id = p_guest_id;
    
    -- B. MOVE FAVORITES
    UPDATE public.user_favorites SET user_id = p_auth_id WHERE user_id = p_guest_id;

    -- C. MERGE WALLETS
    SELECT balance INTO v_guest_bal FROM public.wallets WHERE user_id = p_guest_id;
    IF FOUND THEN
        SELECT balance INTO v_auth_bal FROM public.wallets WHERE user_id = p_auth_id;
        IF FOUND THEN
            -- Add guest money to existing auth account
            UPDATE public.wallets SET balance = balance + v_guest_bal WHERE user_id = p_auth_id;
            DELETE FROM public.wallets WHERE user_id = p_guest_id;
        ELSE
            -- Move guest account to auth account
            UPDATE public.wallets SET user_id = p_auth_id WHERE user_id = p_guest_id;
        END IF;
    END IF;

    -- D. MOVE ADDRESSES
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'user_addresses') THEN
        EXECUTE 'UPDATE public.user_addresses SET user_id = $1 WHERE user_id = $2' USING p_auth_id, p_guest_id;
    END IF;
    
    -- E. CONSOLIDATE PROFILE
    UPDATE public.customer_profiles cp
    SET 
        full_name = COALESCE(cp.full_name, g.full_name),
        email = COALESCE(cp.email, g.email)
    FROM public.customer_profiles g
    WHERE cp.id = p_auth_id AND g.id = p_guest_id;
    
    DELETE FROM public.customer_profiles WHERE id = p_guest_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. THE ULTIMATE BOOTSTRAP DATA (V6 - Joined Favorites & Type Safe)
CREATE OR REPLACE FUNCTION public.get_unified_bootstrap_data(p_user_id TEXT, p_role TEXT DEFAULT 'customer')
RETURNS JSONB AS $$
DECLARE
    v_profile JSONB;
    v_orders JSONB;
    v_favorites JSONB;
    v_vendor_ids UUID[];
BEGIN
    IF p_role = 'vendor' THEN
        SELECT array_agg(id) INTO v_vendor_ids FROM public.vendors WHERE owner_id::TEXT = p_user_id;
        SELECT row_to_json(v) INTO v_profile FROM public.vendors WHERE owner_id::TEXT = p_user_id LIMIT 1;
        SELECT json_agg(o) INTO v_orders FROM public.order_details_v3 o WHERE o.vendor_id = ANY(v_vendor_ids) ORDER BY o.created_at DESC LIMIT 50;
        
        RETURN jsonb_build_object(
            'profile', v_profile,
            'orders', COALESCE(v_orders, '[]'::jsonb),
            'role', 'vendor'
        );
    ELSE
        -- CUSTOMER PATH
        SELECT row_to_json(p) INTO v_profile FROM public.customer_profiles p WHERE p.id::TEXT = p_user_id;
        
        SELECT json_agg(o) INTO v_orders FROM public.order_details_v3 o WHERE o.customer_id::TEXT = p_user_id ORDER BY o.created_at DESC LIMIT 20;

        -- Get Favorites with JOINED DETAILS
        SELECT json_agg(fav_data) INTO v_favorites FROM (
            SELECT f.*, 
                   row_to_json(v) as vendor_details,
                   row_to_json(p) as product_details
            FROM public.user_favorites f
            LEFT JOIN public.vendors v ON f.vendor_id = v.id
            LEFT JOIN public.products p ON f.product_id = p.id
            WHERE f.user_id::TEXT = p_user_id
        ) fav_data;
        
        RETURN jsonb_build_object(
            'profile', v_profile,
            'orders', COALESCE(v_orders, '[]'::jsonb),
            'favorites', COALESCE(v_favorites, '[]'::jsonb),
            'role', 'customer'
        );
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
