
-- ULTIMATE PRODUCTION PIPELINE V55.9 (TOTAL IDENTITY UNLOCK)
-- 🎯 MISSION: Fix "22P02 (Invalid UUID)" by migrating ALL identity columns to TEXT.
-- 🛠️ WHY: delivery_address_id and user_addresses.id were still UUID, causing crashes for guest/Firebase users.

BEGIN;

-- 1. DROP DEPENDENT VIEWS
DROP VIEW IF EXISTS public.order_details_v3 CASCADE;

-- 2. DROP BLOCKING POLICIES
DROP POLICY IF EXISTS "Users can view own profile" ON public.customer_profiles;
DROP POLICY IF EXISTS "Users can view own orders" ON public.orders;
DROP POLICY IF EXISTS "Users can view own wallet" ON public.wallets;
DROP POLICY IF EXISTS "Users can view own addresses" ON public.user_addresses;

-- 3. NUCLEAR CONSTRAINT REMOVAL (Postgres-Native)
-- This finds every FK pointing to customer_profiles or user_addresses and drops it.
DO $$ 
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT pc.relname AS table_name, pn.nspname AS schema_name, con.conname AS constraint_name
        FROM pg_constraint con
        JOIN pg_class pc ON con.conrelid = pc.oid
        JOIN pg_namespace pn ON pc.relnamespace = pn.oid
        WHERE con.confrelid IN ('public.customer_profiles'::regclass, 'public.user_addresses'::regclass)
    ) LOOP
        EXECUTE 'ALTER TABLE ' || quote_ident(r.schema_name) || '.' || quote_ident(r.table_name) || ' DROP CONSTRAINT ' || quote_ident(r.constraint_name);
    END LOOP;
END $$;

-- 4. MIGRATE ALL IDENTITY COLUMNS TO TEXT
-- Profile & Wallet
ALTER TABLE public.customer_profiles ALTER COLUMN id TYPE TEXT;
ALTER TABLE public.wallets ALTER COLUMN user_id TYPE TEXT;

-- Orders
ALTER TABLE public.orders ALTER COLUMN customer_id TYPE TEXT;
ALTER TABLE public.orders ALTER COLUMN delivery_address_id TYPE TEXT;

-- Addresses
ALTER TABLE public.user_addresses ALTER COLUMN id TYPE TEXT;
ALTER TABLE public.user_addresses ALTER COLUMN user_id TYPE TEXT;

-- 5. DATA REPAIR (Ensure consistency)
-- Profiles for Orders
INSERT INTO public.customer_profiles (id, full_name, updated_at)
SELECT DISTINCT customer_id, 'Guest Customer', NOW()
FROM public.orders
WHERE customer_id NOT IN (SELECT id FROM public.customer_profiles)
ON CONFLICT (id) DO NOTHING;

-- Profiles for Wallets
INSERT INTO public.customer_profiles (id, full_name, updated_at)
SELECT DISTINCT user_id, 'Guest Wallet', NOW()
FROM public.wallets
WHERE user_id NOT IN (SELECT id FROM public.customer_profiles)
ON CONFLICT (id) DO NOTHING;

-- 6. RE-ESTABLISH CONSTRAINTS (TEXT-to-TEXT)
ALTER TABLE public.orders ADD CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id) REFERENCES public.customer_profiles(id);
ALTER TABLE public.wallets ADD CONSTRAINT fk_wallets_user FOREIGN KEY (user_id) REFERENCES public.customer_profiles(id);
ALTER TABLE public.user_addresses ADD CONSTRAINT fk_address_user FOREIGN KEY (user_id) REFERENCES public.customer_profiles(id);

-- 7. RECREATE THE "TRUTH" VIEW
CREATE OR REPLACE VIEW public.order_details_v3 AS
SELECT 
    o.id, o.created_at, o.customer_id, o.vendor_id, o.total, o.status, o.items,
    o.delivery_lat, o.delivery_lng, o.delivery_address, o.delivery_address_id,
    v.name as vendor_name, cp.full_name as customer_name, cp.phone as customer_phone
FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id = v.id
LEFT JOIN public.customer_profiles cp ON o.customer_id = cp.id;

-- 8. RECREATE POLICIES (TEXT Compatible)
CREATE POLICY "Users can view own profile" ON public.customer_profiles FOR SELECT USING (auth.uid()::TEXT = id);
CREATE POLICY "Users can view own orders" ON public.orders FOR SELECT USING (auth.uid()::TEXT = customer_id);
CREATE POLICY "Users can view own wallet" ON public.wallets FOR SELECT USING (auth.uid()::TEXT = user_id);
CREATE POLICY "Users can view own addresses" ON public.user_addresses FOR SELECT USING (auth.uid()::TEXT = user_id);

-- 9. UPDATE ORDER PLACEMENT (V6 Final)
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
