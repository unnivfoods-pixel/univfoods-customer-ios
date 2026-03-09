-- 🔒 ULTIMATE PRIVACY ENFORCEMENT & IDENTITY REPAIR v1.5
-- 🎯 MISSION: Fix the "Infinite Recursion" error in RLS and allow Admin Panel access.
-- 🛠️ FIXES: 
-- 1. Removed recursion from subqueries (checking phone against same table).
-- 2. Added Admin Bypass for univfoods@gmail.com and service role.
-- 3. Robust View Join restored with fixed columns.

BEGIN;

-- 🛠️ 0. DROP DEPENDENT VIEWS
DROP VIEW IF EXISTS public.order_tracking_details_v1 CASCADE;
DROP VIEW IF EXISTS public.order_details_v3 CASCADE;
DROP VIEW IF EXISTS public.active_orders_view CASCADE;

-- 🛠️ 1. ENABLE ROW LEVEL SECURITY
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;

-- 🛠️ 2. CREATE HELPER TO DETECT ADMIN
-- This avoids recursion and provides a clean bypass.
CREATE OR REPLACE FUNCTION public.is_admin() 
RETURNS BOOLEAN AS $$
BEGIN
  RETURN (
    auth.jwt() ->> 'email' = 'univfoods@gmail.com' 
    OR auth.role() = 'service_role'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 🛠️ 3. NON-RECURSIVE POLICIES
-- Profiles Policy (FIXED RECURSION)
DROP POLICY IF EXISTS "Users can see and update their own profile" ON public.customer_profiles;
CREATE POLICY "Users can see and update their own profile" ON public.customer_profiles
    FOR ALL USING (
        id = auth.uid()::text 
        OR public.is_admin()
    );

-- Orders Policy (FIXED RECURSION)
DROP POLICY IF EXISTS "Users see their own orders" ON public.orders;
CREATE POLICY "Users see their own orders" ON public.orders
    FOR SELECT USING (
        customer_id = auth.uid()::text 
        OR user_id = auth.uid()::text
        OR public.is_admin()
    );

DROP POLICY IF EXISTS "Users manage their own orders" ON public.orders;
CREATE POLICY "Users manage their own orders" ON public.orders
    FOR ALL USING (
        customer_id = auth.uid()::text 
        OR user_id = auth.uid()::text
        OR public.is_admin()
    );

-- Addresses Policy
DROP POLICY IF EXISTS "Users manage their own addresses" ON public.user_addresses;
CREATE POLICY "Users manage their own addresses" ON public.user_addresses
    FOR ALL USING (
        user_id = auth.uid()::text
        OR public.is_admin()
    );

-- Favorites Policy
DROP POLICY IF EXISTS "Users manage their own favorites" ON public.user_favorites;
CREATE POLICY "Users manage their own favorites" ON public.user_favorites
    FOR ALL USING (
        user_id = auth.uid()::text
        OR public.is_admin()
    );

-- 🛠️ 4. PUBLIC ACCESS
ALTER TABLE public.vendors ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public can view vendors" ON public.vendors;
CREATE POLICY "Public can view vendors" ON public.vendors FOR SELECT USING (true);

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public can view products" ON public.products;
CREATE POLICY "Public can view products" ON public.products FOR SELECT USING (true);

-- 🛠️ 5. VIEW RESTORATION
CREATE OR REPLACE VIEW public.order_details_v3 AS
SELECT 
    o.id, o.customer_id, o.vendor_id, o.items, o.total, o.status, o.payment_method, o.payment_status,
    o.delivery_address, o.delivery_pincode, o.delivery_house_number, o.delivery_phone,
    o.vendor_lat, o.vendor_lng, o.delivery_lat, o.delivery_lng,
    o.cooking_instructions, o.created_at, o.rider_id, o.assigned_at,
    o.id::TEXT as order_id,
    v.name as vendor_name,
    v.logo_url as vendor_logo_url,
    p.full_name as profile_customer_name,
    p.phone as profile_customer_phone,
    o.customer_name as snapshot_customer_name,
    o.customer_phone as snapshot_customer_phone
FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id::TEXT = v.id::TEXT
LEFT JOIN public.customer_profiles p ON (o.customer_id::TEXT = p.id::TEXT OR o.customer_id::TEXT = p.phone::TEXT);

CREATE OR REPLACE VIEW public.order_tracking_details_v1 AS 
SELECT * FROM public.order_details_v3;

COMMIT;
SELECT 'PRIVACY & IDENTITY REPAIR v1.5 COMPLETE - RECURSION FIXED' as status;
