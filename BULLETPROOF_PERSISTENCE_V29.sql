-- 🛡️ BULLETPROOF PERMANENT PERSISTENCE (V29.2)
-- 🎯 MISSION: Permanent data for Guests & Logged-in users. Kill "COD Error" & "shell UUID".
-- 🎯 MISSION: Fix "uuid ~~ unknown" (LIKE operator) error.

BEGIN;

-- ==========================================================
-- � 1. UNLOCK DEPENDENCIES
-- ==========================================================
-- Drop views that depend on the columns we are about to change.
DROP VIEW IF EXISTS public.order_details_v3 CASCADE;
DROP VIEW IF EXISTS public.order_details_v2 CASCADE;
DROP VIEW IF EXISTS public.order_details_v1 CASCADE;

-- ==========================================================
-- 🛠️ 2. DATA HEALING (Forced Type Alignment)
-- ==========================================================
-- Drop all policies first to prevent dependency errors during type change.
DROP POLICY IF EXISTS "Users can manage own favorites" ON public.user_favorites;
DROP POLICY IF EXISTS "Users can view own orders" ON public.orders;
DROP POLICY IF EXISTS "Users can view own profile" ON public.customer_profiles;
DROP POLICY IF EXISTS "Users can view own wallet" ON public.wallets;

-- Convert ID columns to TEXT to allow Guest IDs (guest_...) and Auth UIDs.
DO $$ 
BEGIN
    -- user_favorites (The one likely causing the 'uuid ~~ unknown' error)
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_favorites' AND column_name='user_id') THEN
        ALTER TABLE public.user_favorites ALTER COLUMN user_id TYPE TEXT;
    END IF;

    -- orders
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='customer_id') THEN
        ALTER TABLE public.orders ALTER COLUMN customer_id TYPE TEXT;
    END IF;

    -- customer_profiles
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='customer_profiles' AND column_name='id') THEN
        ALTER TABLE public.customer_profiles ALTER COLUMN id TYPE TEXT;
    END IF;

    -- wallets
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='wallets' AND column_name='user_id') THEN
        ALTER TABLE public.wallets ALTER COLUMN user_id TYPE TEXT;
    END IF;

EXCEPTION WHEN OTHERS THEN 
    RAISE NOTICE 'Caught error during type healing: %', SQLERRM;
END $$;

-- ==========================================================
-- 🔐 3. SECURITY RESTORATION
-- ==========================================================
-- Re-create policies with explicit casting to avoid any future "operator does not exist" errors.
ALTER TABLE public.user_favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own favorites" ON public.user_favorites 
FOR ALL USING (user_id::TEXT = auth.uid()::TEXT OR user_id::TEXT LIKE 'guest_%');

CREATE POLICY "Users can view own orders" ON public.orders 
FOR ALL USING (customer_id::TEXT = auth.uid()::TEXT OR customer_id::TEXT LIKE 'guest_%');

CREATE POLICY "Users can view own profile" ON public.customer_profiles 
FOR ALL USING (id::TEXT = auth.uid()::TEXT OR id::TEXT LIKE 'guest_%');

CREATE POLICY "Users can view own wallet" ON public.wallets 
FOR ALL USING (user_id::TEXT = auth.uid()::TEXT OR user_id::TEXT LIKE 'guest_%');

-- ==========================================================
-- 🏢 4. VIEW RESTORATION
-- ==========================================================
-- Recreate the orders view with text-compatible joins.
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

-- ==========================================================
-- 🚢 5. IDENTITY MIGRATION ENGINE
-- ==========================================================
CREATE OR REPLACE FUNCTION public.migrate_guest_orders_v5(p_guest_id TEXT, p_auth_id TEXT)
RETURNS VOID AS $$
BEGIN
    UPDATE public.orders SET customer_id = p_auth_id WHERE customer_id = p_guest_id;
    UPDATE public.user_favorites SET user_id = p_auth_id WHERE user_id = p_guest_id;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='wallets') THEN
        UPDATE public.wallets SET user_id = p_auth_id WHERE user_id = p_guest_id;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='user_addresses') THEN
        UPDATE public.user_addresses SET user_id = p_auth_id WHERE user_id = p_guest_id;
    END IF;

    DELETE FROM public.customer_profiles WHERE id = p_guest_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
