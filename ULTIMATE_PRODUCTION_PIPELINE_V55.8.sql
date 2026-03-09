
-- ULTIMATE PRODUCTION PIPELINE V55.8 (INTEGRITY HEALING)
-- 🎯 MISSION: Fix "foreign key constraint violation" during type migration.
-- 🛠️ WHY: You have "orphan" records in wallets/orders that don't have a profile.

BEGIN;

-- 1. DROP DEPENDENT VIEWS (CASCADE)
DROP VIEW IF EXISTS public.order_details_v3 CASCADE;

-- 2. DROP BLOCKING POLICIES
DROP POLICY IF EXISTS "Users can view own profile" ON public.customer_profiles;
DROP POLICY IF EXISTS "Individuals can view their own profile" ON public.customer_profiles;
DROP POLICY IF EXISTS "Users can view own orders" ON public.orders;
DROP POLICY IF EXISTS "Users can view own wallet" ON public.wallets;

-- 3. DROP FOREIGN KEYS (Postgres-Native Query)
DO $$ 
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT pc.relname AS table_name, pn.nspname AS schema_name, con.conname AS constraint_name
        FROM pg_constraint con
        JOIN pg_class pc ON con.conrelid = pc.oid
        JOIN pg_namespace pn ON pc.relnamespace = pn.oid
        WHERE con.confrelid = 'public.customer_profiles'::regclass
    ) LOOP
        EXECUTE 'ALTER TABLE ' || quote_ident(r.schema_name) || '.' || quote_ident(r.table_name) || ' DROP CONSTRAINT ' || quote_ident(r.constraint_name);
    END LOOP;
END $$;

-- 4. MIGRATE IDENTITY COLUMNS TO TEXT
ALTER TABLE public.customer_profiles ALTER COLUMN id TYPE TEXT;
ALTER TABLE public.orders ALTER COLUMN customer_id TYPE TEXT;
ALTER TABLE public.wallets ALTER COLUMN user_id TYPE TEXT;

-- 5. 🛠️ DATA INTEGRITY HEALING (The Fix)
-- Insert missing profiles for any ID that exists in wallets or orders but not in profiles.
INSERT INTO public.customer_profiles (id, full_name, updated_at)
SELECT DISTINCT user_id, 'System/Guest User', NOW()
FROM public.wallets
WHERE user_id NOT IN (SELECT id FROM public.customer_profiles)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.customer_profiles (id, full_name, updated_at)
SELECT DISTINCT customer_id, 'Ordered via Guest', NOW()
FROM public.orders
WHERE customer_id NOT IN (SELECT id FROM public.customer_profiles)
ON CONFLICT (id) DO NOTHING;

-- 6. RE-ESTABLISH FOREIGN KEYS (Now guaranteed to succeed)
ALTER TABLE public.orders ADD CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id) REFERENCES public.customer_profiles(id);
ALTER TABLE public.wallets ADD CONSTRAINT fk_wallets_user FOREIGN KEY (user_id) REFERENCES public.customer_profiles(id);

-- 7. RECREATE THE "TRUTH" VIEW
CREATE OR REPLACE VIEW public.order_details_v3 AS
SELECT 
    o.id, o.created_at, o.customer_id, o.vendor_id, o.total, o.status, o.items,
    o.delivery_lat, COALESCE(o.delivery_lng, o.delivery_long) as delivery_lng,
    v.name as vendor_name, cp.full_name as customer_name, cp.phone as customer_phone
FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id = v.id
LEFT JOIN public.customer_profiles cp ON o.customer_id = cp.id;

-- 8. RECREATE POLICIES (TEXT Compatible)
CREATE POLICY "Users can view own profile" ON public.customer_profiles
    FOR SELECT USING (auth.uid()::TEXT = id);

CREATE POLICY "Users can view own orders" ON public.orders
    FOR SELECT USING (auth.uid()::TEXT = customer_id);

CREATE POLICY "Users can view own wallet" ON public.wallets
    FOR SELECT USING (auth.uid()::TEXT = user_id);

-- 9. HEAL BOOTSTRAP ENGINE
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
