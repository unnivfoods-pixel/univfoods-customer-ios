
-- ULTIMATE PRODUCTION PIPELINE V55.6 (NUCLEAR POLICY UNLOCKING)
-- 🎯 MISSION: Fix "cannot alter type of a column used in a policy definition" for customer_profiles.
-- 🛠️ WHY: Policies or Foreign Keys on "id" are blocking the TEXT migration.

BEGIN;

-- 1. DROP ALL DEPENDENT VIEWS (CASCADE for safety)
DROP VIEW IF EXISTS public.order_details_v3 CASCADE;

-- 2. DROP ALL KNOWN POLICIES THAT MIGHT BLOCK ID CHANGES
-- We drop by every possible name we've used or seen in errors.
DROP POLICY IF EXISTS "Users can view own profile" ON public.customer_profiles;
DROP POLICY IF EXISTS "Individuals can view their own profile" ON public.customer_profiles;
DROP POLICY IF EXISTS "Allow individual read" ON public.customer_profiles;
DROP POLICY IF EXISTS "Users can view own orders" ON public.orders;
DROP POLICY IF EXISTS "View own orders" ON public.orders;
DROP POLICY IF EXISTS "Users can view own wallet" ON public.wallets;

-- 3. DROP FOREIGN KEYS TEMPORARILY (Crucial for changing Primary Key types)
-- If orders.customer_id is a FK to customer_profiles.id, we must drop it.
DO $$ 
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT tc.constraint_name, tc.table_name 
        FROM information_schema.table_constraints tc 
        JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name 
        WHERE tc.constraint_type = 'FOREIGN KEY' 
          AND kcu.referenced_table_name = 'customer_profiles'
    ) LOOP
        EXECUTE 'ALTER TABLE public.' || r.table_name || ' DROP CONSTRAINT ' || r.constraint_name;
    END LOOP;
END $$;

-- 4. MIGRATE IDENTITY COLUMNS TO TEXT
-- This is the core change to support Firebase/Guest IDs.
ALTER TABLE public.customer_profiles ALTER COLUMN id TYPE TEXT;
ALTER TABLE public.orders ALTER COLUMN customer_id TYPE TEXT;
ALTER TABLE public.wallets ALTER COLUMN user_id TYPE TEXT;

-- 5. RE-ESTABLISH FOREIGN KEYS (Now with TEXT-to-TEXT matching)
ALTER TABLE public.orders ADD CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id) REFERENCES public.customer_profiles(id);
ALTER TABLE public.wallets ADD CONSTRAINT fk_wallets_user FOREIGN KEY (user_id) REFERENCES public.customer_profiles(id);

-- 6. RECREATE THE "TRUTH" VIEW
CREATE OR REPLACE VIEW public.order_details_v3 AS
SELECT 
    o.id, o.created_at, o.customer_id, o.vendor_id, o.total, o.status, o.items,
    o.delivery_lat, COALESCE(o.delivery_lng, o.delivery_long) as delivery_lng,
    v.name as vendor_name, cp.full_name as customer_name, cp.phone as customer_phone
FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id = v.id
LEFT JOIN public.customer_profiles cp ON o.customer_id = cp.id;

-- 7. RECREATE POLICIES (TEXT Compatible)
ALTER TABLE public.customer_profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own profile" ON public.customer_profiles
    FOR SELECT USING (auth.uid()::TEXT = id);

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own orders" ON public.orders
    FOR SELECT USING (auth.uid()::TEXT = customer_id);

ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own wallet" ON public.wallets
    FOR SELECT USING (auth.uid()::TEXT = user_id);

-- 8. HEAL BOOTSTRAP FUNCTION
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
