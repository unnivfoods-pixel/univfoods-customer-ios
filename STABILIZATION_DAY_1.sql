-- 🚀 DAY 1: USER ISOLATION + AUTH FIX (CORRECTED)
-- Goal: Strictly enforce data isolation using Supabase RLS with cast safety.

BEGIN;

-- 1. Enable RLS on all primary tables
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.delivery_riders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_favorites ENABLE ROW LEVEL SECURITY;

-- 2. Drop legacy lenient policies
DROP POLICY IF EXISTS "Public Select Profiles" ON customer_profiles;
DROP POLICY IF EXISTS "Public Insert Profiles" ON customer_profiles;
DROP POLICY IF EXISTS "Public Update Profiles" ON customer_profiles;
DROP POLICY IF EXISTS "Users can see their own orders" ON orders;
DROP POLICY IF EXISTS "Customers see own orders" ON public.orders;
DROP POLICY IF EXISTS "Vendors see own orders" ON public.orders;
DROP POLICY IF EXISTS "Riders see own orders" ON public.orders;
DROP POLICY IF EXISTS "Admins see all orders" ON public.orders;

-- 3. ORDERS ISOLATION
-- Use explicit casting to avoid uuid/text mismatches
CREATE POLICY "Customers see own orders" ON public.orders
FOR SELECT USING ((auth.uid()::text) = (customer_id::text));

CREATE POLICY "Vendors see own orders" ON public.orders
FOR SELECT USING ((auth.uid()::text) = (vendor_id::text));

CREATE POLICY "Riders see own orders" ON public.orders
FOR SELECT USING ((auth.uid()::text) = (rider_id::text));

CREATE POLICY "Admins see all orders" ON public.orders
FOR ALL USING (
    (auth.jwt()->>'role' = 'admin') OR 
    (auth.jwt()->>'email' = 'admin@univfoods.in')
);

-- 4. NOTIFICATIONS ISOLATION
CREATE POLICY "Users see own notifications" ON public.notifications
FOR SELECT USING ((auth.uid()::text) = (user_id::text) OR user_id = 'BROADCAST');

-- 5. PROFILE ISOLATION
CREATE POLICY "Users see own profile" ON public.customer_profiles
FOR SELECT USING ((auth.uid()::text) = (id::text));

CREATE POLICY "Users update own profile" ON public.customer_profiles
FOR UPDATE USING ((auth.uid()::text) = (id::text));

-- 6. WALLET ISOLATION
CREATE POLICY "Users see own wallet" ON public.wallets
FOR SELECT USING ((auth.uid()::text) = (user_id::text));

-- 7. ADDRESSES/FAVORITES
CREATE POLICY "Users manage own addresses" ON public.user_addresses
FOR ALL USING ((auth.uid()::text) = (user_id::text));

CREATE POLICY "Users manage own favorites" ON public.user_favorites
FOR ALL USING ((auth.uid()::text) = (user_id::text));

-- 8. VENDOR ISOLATION
DROP POLICY IF EXISTS "Vendors manage own profile" ON public.vendors;
CREATE POLICY "Vendors manage own profile" ON public.vendors
FOR ALL USING ((auth.uid()::text) = (id::text));

-- 9. DELIVERY ISOLATION
DROP POLICY IF EXISTS "Riders manage own settings" ON public.delivery_riders;
CREATE POLICY "Riders manage own settings" ON public.delivery_riders
FOR ALL USING ((auth.uid()::text) = (id::text));

COMMIT;
