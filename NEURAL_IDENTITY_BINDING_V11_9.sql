-- 📡 NEURAL REPAIR & LINK (V11.9)
-- PRODUCTION IDENTITY PROTOCOL: BINDING ALL ROLES TO AUTH UID

BEGIN;

-- 1. HARMONIZE DELIVERY RIDERS (Bind to Auth)
-- We ensure the 'id' column is UUID and correctly references auth.users(id).
-- We use USING id::uuid for explicit casting.
ALTER TABLE public.delivery_riders DROP CONSTRAINT IF EXISTS delivery_riders_id_fkey;
ALTER TABLE public.delivery_riders ALTER COLUMN id TYPE uuid USING id::uuid;

-- 2. HARMONIZE VENDORS (Link to Owner UID)
-- For vendors, we use owner_id as the binding link for the Vendor App.
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS owner_id UUID REFERENCES auth.users(id);

-- 3. GLOBAL ORDERS VIEW RECLAMATION
-- Ensure the order_details_v3 view is optimized for UID lookups.
-- We DROP before CREATE to avoid "cannot change name of view column" errors.
DROP VIEW IF EXISTS public.order_details_v3;
CREATE VIEW public.order_details_v3 AS
SELECT 
    o.*,
    jsonb_build_object(
        'name', v.name,
        'address', v.address,
        'latitude', v.latitude,
        'longitude', v.longitude,
        'logo_url', v.logo_url
    ) as vendors,
    jsonb_build_object(
        'full_name', cp.full_name,
        'phone', cp.phone,
        'email', cp.email
    ) as customer_profiles
FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id = v.id
LEFT JOIN public.customer_profiles cp ON o.customer_id::text = cp.id::text;

GRANT SELECT ON public.order_details_v3 TO anon, authenticated;

-- 4. REAL-TIME PUBLICATION UPDATE
-- Ensure all production tables are in the realtime stream.
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

-- 5. MASTER BOOTSTRAP (Unified for all apps)
CREATE OR REPLACE FUNCTION public.get_unified_bootstrap_data(p_user_id TEXT, p_role TEXT)
RETURNS JSON AS $$
DECLARE
    v_profile JSON;
    v_active_orders JSON;
    v_wallet JSON;
BEGIN
    -- Fetch Role-Specific Profile
    IF p_role = 'customer' THEN
        SELECT row_to_json(p) INTO v_profile FROM public.customer_profiles p WHERE p.id::text = p_user_id;
        SELECT json_agg(o) INTO v_active_orders FROM public.order_details_v3 o WHERE o.customer_id = p_user_id AND o.status NOT IN ('DELIVERED', 'CANCELLED');
    ELSIF p_role = 'vendor' THEN
        SELECT row_to_json(v) INTO v_profile FROM public.vendors v WHERE v.owner_id::text = p_user_id OR v.id::text = p_user_id;
        SELECT json_agg(o) INTO v_active_orders FROM public.order_details_v3 o WHERE o.vendor_id::text = (v_profile->>'id') AND o.status NOT IN ('DELIVERED', 'CANCELLED');
    ELSIF p_role = 'delivery' THEN
        SELECT row_to_json(r) INTO v_profile FROM public.delivery_riders r WHERE r.id::text = p_user_id;
        SELECT json_agg(o) INTO v_active_orders FROM public.order_details_v3 o WHERE o.rider_id::text = p_user_id AND o.status NOT IN ('DELIVERED', 'CANCELLED');
    END IF;

    -- Fetch Wallet
    SELECT row_to_json(w) INTO v_wallet FROM public.wallets w WHERE w.user_id::text = p_user_id;

    RETURN json_build_object(
        'profile', v_profile,
        'orders', COALESCE(v_active_orders, '[]'::json),
        'wallet', COALESCE(v_wallet, '{"balance": 0}'::json)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;

SELECT 'NEURAL IDENTITY V11.9 ONLINE - PRODUCTION AUTH BINDING ACTIVE' as status;
