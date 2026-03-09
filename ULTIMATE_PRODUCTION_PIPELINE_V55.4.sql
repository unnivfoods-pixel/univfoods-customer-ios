
-- ULTIMATE PRODUCTION PIPELINE V55.4 (FORCED IDENTITY MIGRATION)
-- 🎯 MISSION: Fix "cannot alter type of a column used in a policy definition".
-- 🛠️ WHY: RLS Policies block column changes. We must drop, alter, and restore.

BEGIN;

-- 1. DROP DEPENDENT POLICIES (IDENTIFIED FROM ERROR)
DROP POLICY IF EXISTS "Users can view own orders" ON public.orders;
DROP POLICY IF EXISTS "View own orders" ON public.orders;
DROP POLICY IF EXISTS "Allow individual read" ON public.orders;
DROP POLICY IF EXISTS "Individuals can view their own profile" ON public.customer_profiles;
DROP POLICY IF EXISTS "Users can view own wallet" ON public.wallets;
DROP POLICY IF EXISTS "Users can view own addresses" ON public.user_addresses;

-- 2. ALTER COLUMNS TO TEXT (To support Firebase/Guest IDs)
-- Orders Table
ALTER TABLE public.orders ALTER COLUMN customer_id TYPE TEXT;

-- Profiles Table (Handle PK carefully)
-- We use a more aggressive approach for the PK if needed, 
-- but usually altering the type is allowed if we drop foreign keys temporarily.
-- For now, focusing on the columns reported in the identity error.
ALTER TABLE public.customer_profiles ALTER COLUMN id TYPE TEXT;

-- Wallets Table
ALTER TABLE public.wallets ALTER COLUMN user_id TYPE TEXT;

-- Addresses Table
DO $$ 
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'user_addresses') THEN
        ALTER TABLE public.user_addresses ALTER COLUMN user_id TYPE TEXT;
    END IF;
END $$;


-- 3. RECREATE POLICIES (With TEXT compatibility)
-- Note: auth.uid() returns a UUID, so we cast it to TEXT for comparison.

CREATE POLICY "Users can view own orders" ON public.orders
    FOR SELECT USING (auth.uid()::TEXT = customer_id);

CREATE POLICY "Individuals can view their own profile" ON public.customer_profiles
    FOR SELECT USING (auth.uid()::TEXT = id);

CREATE POLICY "Users can view own wallet" ON public.wallets
    FOR SELECT USING (auth.uid()::TEXT = user_id);

-- 4. RESTORE ORDER PLACEMENT
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
    IF p_payment_method = 'UPI' OR p_payment_method = 'CARD' THEN
        v_initial_status := 'PAYMENT_PENDING';
    ELSE
        v_initial_status := 'PLACED';
    END IF;

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
