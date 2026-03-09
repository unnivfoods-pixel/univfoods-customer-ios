-- 🚨 NUCLEAR ID HARMONY MIGRATION (V13.1) - FAIL-SAFE VERSION
-- Purpose: Convert all UUID-based IDs to TEXT with safety checks for missing tables.
-- Run this in Supabase SQL Editor.

DO $$ 
BEGIN
    -- 1. DROP CONSTRAINTS (Fail-safe)
    PERFORM 1 FROM pg_constraint WHERE conname = 'orders_customer_id_fkey';
    IF FOUND THEN ALTER TABLE public.orders DROP CONSTRAINT orders_customer_id_fkey; END IF;
    
    PERFORM 1 FROM pg_constraint WHERE conname = 'orders_rider_id_fkey';
    IF FOUND THEN ALTER TABLE public.orders DROP CONSTRAINT orders_rider_id_fkey; END IF;

    -- 2. CORE TYPE CONVERSIONS (Guaranteed Tables)
    ALTER TABLE public.customer_profiles ALTER COLUMN id TYPE TEXT;
    ALTER TABLE public.delivery_riders ALTER COLUMN id TYPE TEXT;
    ALTER TABLE public.orders ALTER COLUMN customer_id TYPE TEXT;
    ALTER TABLE public.orders ALTER COLUMN rider_id TYPE TEXT;
    ALTER TABLE public.orders ALTER COLUMN delivery_partner_id TYPE TEXT;
    ALTER TABLE public.order_tracking ALTER COLUMN rider_id TYPE TEXT;
    ALTER TABLE public.wallets ALTER COLUMN user_id TYPE TEXT;
    ALTER TABLE public.withdrawals ALTER COLUMN user_id TYPE TEXT;
    ALTER TABLE public.notifications ALTER COLUMN user_id TYPE TEXT;
    ALTER TABLE public.chat_messages ALTER COLUMN sender_id TYPE TEXT;

    -- 3. OPTIONAL TABLES (Fail-safe checks)
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'user_fcm_tokens') THEN
        ALTER TABLE public.user_fcm_tokens ALTER COLUMN user_id TYPE TEXT;
    END IF;

    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'user_addresses') THEN
        ALTER TABLE public.user_addresses ALTER COLUMN user_id TYPE TEXT;
    END IF;

END $$;

-- 4. REPAIR RPCs (Cleaned of UUID casts)
CREATE OR REPLACE FUNCTION public.migrate_guest_orders(p_guest_id TEXT, p_auth_id TEXT)
RETURNS VOID AS $$
BEGIN
    UPDATE public.orders SET customer_id = p_auth_id WHERE customer_id = p_guest_id;
    UPDATE public.wallets SET user_id = p_auth_id WHERE user_id = p_guest_id;
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'user_addresses') THEN
        EXECUTE 'UPDATE public.user_addresses SET user_id = $1 WHERE user_id = $2' USING p_auth_id, p_guest_id;
    END IF;
    
    INSERT INTO public.customer_profiles (id, full_name, phone)
    SELECT p_auth_id, full_name, phone
    FROM public.customer_profiles WHERE id = p_guest_id
    ON CONFLICT (id) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. REPAIR VIEW
DROP VIEW IF EXISTS public.order_details_v3;
CREATE VIEW public.order_details_v3 AS
SELECT 
    o.*,
    jsonb_build_object(
        'id', v.id,
        'name', v.name,
        'latitude', v.latitude,
        'longitude', v.longitude
    ) as vendors,
    jsonb_build_object(
        'full_name', cp.full_name,
        'phone', cp.phone
    ) as customer_profiles
FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id = v.id
LEFT JOIN public.customer_profiles cp ON o.customer_id = cp.id;
