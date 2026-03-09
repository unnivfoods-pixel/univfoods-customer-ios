
-- NUCLEAR IDENTITY & BOOTSTRAP RESTORATION V57.2
-- 🎯 MISSION: Fix "Cannot alter column used in policy" (0A000) and restore all app data.
-- 🛠️ WHY: Policies on Vendors and Riders were blocking the column type change.
-- 🧪 IDENTITY: Complete TEXT-based unlock for all roles.

BEGIN;

-- 1. DROP DEPENDENT VIEWS (Nuclear)
DROP VIEW IF EXISTS public.order_details_v3 CASCADE;

-- 2. DROP BLOCKING POLICIES (Comprehensive)
-- We drop everything on Vendors and Riders to clear the path for column changes.
DO $$ 
DECLARE
    pol RECORD;
BEGIN
    FOR pol IN (
        SELECT policyname, tablename 
        FROM pg_policies 
        WHERE schemaname = 'public' 
          AND tablename IN ('vendors', 'delivery_riders', 'orders', 'order_live_tracking')
    ) LOOP
        EXECUTE 'DROP POLICY IF EXISTS ' || quote_ident(pol.policyname) || ' ON public.' || quote_ident(pol.tablename);
    END LOOP;
END $$;

-- 3. DROP CONSTRAINTS (Fleet)
DO $$ 
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT pc.relname AS table_name, pn.nspname AS schema_name, con.conname AS constraint_name
        FROM pg_constraint con
        JOIN pg_class pc ON con.conrelid = pc.oid
        JOIN pg_namespace pn ON pc.relnamespace = pn.oid
        WHERE con.confrelid IN ('public.delivery_riders'::regclass, 'public.vendors'::regclass)
    ) LOOP
        EXECUTE 'ALTER TABLE ' || quote_ident(r.schema_name) || '.' || quote_ident(r.table_name) || ' DROP CONSTRAINT ' || quote_ident(r.constraint_name);
    END LOOP;
END $$;

-- 4. MIGRATE ALL REMAINING IDENTITY COLUMNS TO TEXT
-- This is what allows your Firebase logins to work
ALTER TABLE public.vendors ALTER COLUMN owner_id TYPE TEXT;
ALTER TABLE public.delivery_riders ALTER COLUMN id TYPE TEXT;
ALTER TABLE public.orders ALTER COLUMN rider_id TYPE TEXT;
ALTER TABLE public.order_live_tracking ALTER COLUMN rider_id TYPE TEXT;

-- 5. DATA REPAIR: Ensure IDs are trimmed and clean
UPDATE public.vendors SET owner_id = TRIM(owner_id) WHERE owner_id IS NOT NULL;
UPDATE public.delivery_riders SET id = TRIM(id);

-- 6. RESTORE THE "TRUTH" VIEW (Full Identity Coverage)
CREATE OR REPLACE VIEW public.order_details_v3 AS
SELECT 
    o.id, o.created_at, o.customer_id, o.vendor_id, o.total, o.status, o.items,
    o.delivery_lat, o.delivery_lng, o.delivery_address, o.delivery_address_id,
    o.rider_id, o.payment_type, o.payment_status,
    v.name as vendor_name, v.address as vendor_address, v.owner_id as vendor_owner_id,
    cp.full_name as customer_name, cp.phone as customer_phone,
    dr.name as rider_name, dr.phone as rider_phone,
    CASE 
        WHEN o.status = 'PLACED' THEN 'New'
        WHEN o.status = 'ACCEPTED' THEN 'Preparing'
        WHEN o.status = 'READY_FOR_PICKUP' THEN 'Ready'
        WHEN o.status = 'DELIVERED' THEN 'Completed'
        WHEN o.status = 'CANCELLED' THEN 'Cancelled'
        ELSE UPPER(o.status)
    END as status_display
FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id = v.id
LEFT JOIN public.customer_profiles cp ON o.customer_id = cp.id
LEFT JOIN public.delivery_riders dr ON o.rider_id = dr.id;

-- 7. RECREATE POLICIES (TEXT-Native & Secure)
CREATE POLICY "Vendors: Select own profile" ON public.vendors FOR SELECT USING (auth.uid()::TEXT = owner_id);
CREATE POLICY "Vendors: Update own profile" ON public.vendors FOR UPDATE USING (auth.uid()::TEXT = owner_id);
CREATE POLICY "Riders: Select own profile" ON public.delivery_riders FOR SELECT USING (auth.uid()::TEXT = id);
CREATE POLICY "Riders: Update own profile" ON public.delivery_riders FOR UPDATE USING (auth.uid()::TEXT = id);
CREATE POLICY "Orders: Viewable by linked partners" ON public.orders FOR SELECT USING (
    auth.uid()::TEXT = customer_id OR 
    EXISTS (SELECT 1 FROM public.vendors WHERE id = orders.vendor_id AND owner_id = auth.uid()::TEXT) OR
    auth.uid()::TEXT = rider_id
);

-- 8. THE SUPER BOOTSTRAP (Unified, Multi-Role, TEXT-Native)
CREATE OR REPLACE FUNCTION public.get_unified_bootstrap_data(p_user_id TEXT, p_role TEXT DEFAULT 'customer')
RETURNS JSONB AS $$
DECLARE
    v_profile JSONB;
    v_orders JSONB;
    v_wallet JSONB;
    v_menu JSONB;
    v_addresses JSONB;
    v_favorites JSONB;
BEGIN
    -- [A] FINANCIALS (Always Provisioned)
    INSERT INTO public.wallets (user_id, balance) VALUES (p_user_id, 0) ON CONFLICT (user_id) DO NOTHING;
    SELECT row_to_json(w)::jsonb INTO v_wallet FROM public.wallets w WHERE user_id = p_user_id;

    -- [B] ROLE SPECIFIC PROVISIONING
    IF p_role = 'vendor' THEN
        -- Setup helper: If this user owns a 'Royal' vendor or any unassigned vendor, link it.
        UPDATE public.vendors SET owner_id = p_user_id 
        WHERE (owner_id IS NULL OR owner_id = '') 
        AND name ILIKE '%Royal%' 
        AND NOT EXISTS (SELECT 1 FROM public.vendors WHERE owner_id = p_user_id);

        SELECT row_to_json(v)::jsonb INTO v_profile FROM public.vendors v WHERE owner_id = p_user_id LIMIT 1;
        
        IF v_profile IS NOT NULL THEN
            SELECT json_agg(p)::jsonb INTO v_menu FROM public.products p WHERE vendor_id::TEXT = v_profile->>'id';
            SELECT json_agg(o)::jsonb INTO v_orders FROM (
                SELECT * FROM public.order_details_v3 WHERE vendor_id::TEXT = v_profile->>'id' ORDER BY created_at DESC LIMIT 50
            ) o;
        END IF;

    ELSIF p_role = 'delivery' THEN
        INSERT INTO public.delivery_riders (id, name, status) VALUES (p_user_id, 'Pro Rider', 'ONLINE') ON CONFLICT (id) DO NOTHING;
        SELECT row_to_json(r)::jsonb INTO v_profile FROM public.delivery_riders r WHERE id = p_user_id;
        
        SELECT json_agg(o)::jsonb INTO v_orders FROM (
            SELECT * FROM public.order_details_v3 
            WHERE rider_id = p_user_id 
               OR (status IN ('ACCEPTED', 'READY_FOR_PICKUP') AND rider_id IS NULL)
            ORDER BY created_at DESC LIMIT 30
        ) o;

    ELSE -- Customer
        INSERT INTO public.customer_profiles (id, full_name) VALUES (p_user_id, 'Customer Account') ON CONFLICT (id) DO NOTHING;
        SELECT row_to_json(cp)::jsonb INTO v_profile FROM public.customer_profiles cp WHERE id = p_user_id;
        
        SELECT json_agg(a)::jsonb INTO v_addresses FROM public.user_addresses a WHERE user_id = p_user_id;
        SELECT json_agg(f)::jsonb INTO v_favorites FROM public.user_favorites f WHERE user_id = p_user_id;
        SELECT json_agg(o)::jsonb INTO v_orders FROM (
            SELECT * FROM public.order_details_v3 WHERE customer_id = p_user_id ORDER BY created_at DESC LIMIT 20
        ) o;
    END IF;

    -- [D] ASSEMBLE
    RETURN jsonb_build_object(
        'profile', COALESCE(v_profile, '{}'::jsonb),
        'orders', COALESCE(v_orders, '[]'::jsonb),
        'wallet', COALESCE(v_wallet, '{"balance":0}'::jsonb),
        'menu', COALESCE(v_menu, '[]'::jsonb),
        'products', COALESCE(v_menu, '[]'::jsonb),
        'addresses', COALESCE(v_addresses, '[]'::jsonb),
        'favorites', COALESCE(v_favorites, '[]'::jsonb),
        'timestamp', NOW()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
NOTIFY pgrst, 'reload schema';
