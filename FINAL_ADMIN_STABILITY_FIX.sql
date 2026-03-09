-- 🛰️ ULTIMATE ADMIN STABILITY & DATA VISIBILITY FIX
-- Ensures all tables are readable, realtime-enabled, and schema is refreshed.

BEGIN;

-- 1. RECREATE REALTIME PUBLICATION (Include ALL tables)
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

-- 2. RESET RLS POLICIES TO "ADMIN-ONLY" (Permissive for local development)
-- This ensures the 'anon' key used in the dashboard can actually see the data.

-- Vendors
ALTER TABLE public.vendors ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admin All Access Vendors" ON public.vendors;
DROP POLICY IF EXISTS "Allow all vendors" ON public.vendors;
CREATE POLICY "Admin All Access Vendors" ON public.vendors FOR ALL USING (true) WITH CHECK (true);

-- Products
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admin All Access Products" ON public.products;
DROP POLICY IF EXISTS "Allow all products" ON public.products;
CREATE POLICY "Admin All Access Products" ON public.products FOR ALL USING (true) WITH CHECK (true);

-- Orders
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admin All Access Orders" ON public.orders;
DROP POLICY IF EXISTS "Allow all orders" ON public.orders;
CREATE POLICY "Admin All Access Orders" ON public.orders FOR ALL USING (true) WITH CHECK (true);

-- Categories
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admin All Access Categories" ON public.categories;
CREATE POLICY "Admin All Access Categories" ON public.categories FOR ALL USING (true) WITH CHECK (true);

-- Customer Profiles
ALTER TABLE public.customer_profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Super Access Profiles" ON public.customer_profiles;
CREATE POLICY "Super Access Profiles" ON public.customer_profiles FOR ALL USING (true) WITH CHECK (true);

-- Delivery Riders
ALTER TABLE public.delivery_riders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admin All Access Riders" ON public.delivery_riders;
DROP POLICY IF EXISTS "Super Access Riders" ON public.delivery_riders;
CREATE POLICY "Admin All Access Riders" ON public.delivery_riders FOR ALL USING (true) WITH CHECK (true);

-- Notifications
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admin All Access Notifications" ON public.notifications;
DROP POLICY IF EXISTS "Allow all notifications" ON public.notifications;
CREATE POLICY "Admin All Access Notifications" ON public.notifications FOR ALL USING (true) WITH CHECK (true);

-- 3. ENSURE REPLICA IDENTITY (Crucial for Realtime Updates)
ALTER TABLE public.vendors REPLICA IDENTITY FULL;
ALTER TABLE public.products REPLICA IDENTITY FULL;
ALTER TABLE public.orders REPLICA IDENTITY FULL;
ALTER TABLE public.delivery_riders REPLICA IDENTITY FULL;
ALTER TABLE public.notifications REPLICA IDENTITY FULL;

COMMIT;

-- 4. REFRESH SCHEMA CACHE
NOTIFY pgrst, 'reload schema';
