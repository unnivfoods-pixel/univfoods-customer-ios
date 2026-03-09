-- 🚀 REALTIME BOOTSTRAP SYSTEM (v6.0)
-- Centralized API for ultra-fast app startup and realtime alignment.

BEGIN;

-- 1. THE BOOTSTRAP RPC
-- This loads EVERYTHING the user needs in exactly 1 call.
CREATE OR REPLACE FUNCTION public.get_user_bootstrap_data(p_user_id text)
RETURNS json AS $$
DECLARE
    v_profile json;
    v_wallet json;
    v_addresses json;
    v_active_orders json;
    v_recent_history json;
    v_notif_count int;
    v_cod_enabled boolean := true; -- System default
BEGIN
    -- Profile
    SELECT row_to_json(p) INTO v_profile FROM public.customer_profiles p WHERE p.id::text = p_user_id;
    
    -- Wallet
    SELECT row_to_json(w) INTO v_wallet FROM public.wallets w WHERE w.user_id::text = p_user_id;
    IF v_wallet IS NULL THEN
        v_wallet := json_build_object('balance', 0, 'user_id', p_user_id);
    END IF;

    -- Addresses
    SELECT json_agg(a) INTO v_addresses FROM public.user_addresses a WHERE a.user_id::text = p_user_id;

    -- Active Orders (Unfinished)
    SELECT json_agg(o) INTO v_active_orders FROM public.orders o 
    WHERE o.customer_id::text = p_user_id 
    AND o.status NOT IN ('delivered', 'cancelled')
    ORDER BY o.created_at DESC;

    -- Recent History (Last 10)
    SELECT json_agg(o) INTO v_recent_history FROM (
        SELECT * FROM public.orders 
        WHERE customer_id::text = p_user_id 
        ORDER BY created_at DESC 
        LIMIT 10
    ) o;

    -- Notification Count (Unread)
    SELECT count(*)::int INTO v_notif_count FROM public.notifications 
    WHERE user_id::text = p_user_id AND is_read = false;

    RETURN json_build_object(
        'profile', v_profile,
        'wallet', v_wallet,
        'addresses', COALESCE(v_addresses, '[]'::json),
        'active_orders', COALESCE(v_active_orders, '[]'::json),
        'recent_history', COALESCE(v_recent_history, '[]'::json),
        'unread_notifications', v_notif_count,
        'cod_allowed', v_cod_enabled
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. ENSURE WALLET TABLE EXISTS & IS REALTIME
CREATE TABLE IF NOT EXISTS public.wallets (
    user_id text PRIMARY KEY,
    balance decimal(10,2) DEFAULT 0,
    updated_at timestamptz DEFAULT now()
);

-- 3. ENABLE REALTIME ON KEY TABLES
ALTER TABLE public.wallets REPLICA IDENTITY FULL;
ALTER TABLE public.orders REPLICA IDENTITY FULL;
ALTER TABLE public.notifications REPLICA IDENTITY FULL;
ALTER TABLE public.payments REPLICA IDENTITY FULL;

DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.wallets;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- 4. ADMIN OVERRIDE SIGNAL (For blocking/force logout)
-- Adding account_status to profile if missing
DO $$
BEGIN
    ALTER TABLE public.customer_profiles ADD COLUMN IF NOT EXISTS account_status text DEFAULT 'Active';
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

COMMIT;

SELECT 'Bootstrap v6.0 Online!' as status;
