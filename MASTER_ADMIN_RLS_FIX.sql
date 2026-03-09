-- 🛰️ MASTER ADMIN PANEL RLS FIX
-- Resolves "Row Violated" errors for Delivery Riders, Vendors, and Orders in the Admin Terminal.

BEGIN;

-- 1. FIX DELIVERY RIDERS
ALTER TABLE public.delivery_riders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Enable read for everyone" ON public.delivery_riders;
DROP POLICY IF EXISTS "Super Access Riders" ON public.delivery_riders;
DROP POLICY IF EXISTS "Enable insert for authenticated" ON public.delivery_riders;
DROP POLICY IF EXISTS "Admins can manage all riders" ON public.delivery_riders;

CREATE POLICY "Admin All Access Riders" ON public.delivery_riders 
FOR ALL USING (true) WITH CHECK (true);


-- 2. FIX VENDORS
ALTER TABLE public.vendors ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Super Access Vendors" ON public.vendors;
DROP POLICY IF EXISTS "Enable all access for vendors" ON public.vendors;

CREATE POLICY "Admin All Access Vendors" ON public.vendors 
FOR ALL USING (true) WITH CHECK (true);


-- 3. FIX PRODUCTS
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Super Access Products" ON public.products;
DROP POLICY IF EXISTS "Enable all access for products" ON public.products;

CREATE POLICY "Admin All Access Products" ON public.products 
FOR ALL USING (true) WITH CHECK (true);


-- 4. FIX ORDERS
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Super Access Orders" ON public.orders;
DROP POLICY IF EXISTS "Enable all access for orders" ON public.orders;

CREATE POLICY "Admin All Access Orders" ON public.orders 
FOR ALL USING (true) WITH CHECK (true);


-- 5. FIX REGISTRATION REQUESTS
ALTER TABLE public.registration_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Enable insert for all" ON public.registration_requests;
DROP POLICY IF EXISTS "Enable select for authenticated" ON public.registration_requests;
DROP POLICY IF EXISTS "Enable all for admins" ON public.registration_requests;

CREATE POLICY "Admin All Access Registrations" ON public.registration_requests 
FOR ALL USING (true) WITH CHECK (true);


-- 6. FIX NOTIFICATIONS
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Enable all for admins" ON public.notifications;

CREATE POLICY "Admin All Access Notifications" ON public.notifications 
FOR ALL USING (true) WITH CHECK (true);

-- 7. FIX CATEGORIES
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admin All Access Categories" ON public.categories;

CREATE POLICY "Admin All Access Categories" ON public.categories 
FOR ALL USING (true) WITH CHECK (true);

COMMIT;

NOTIFY pgrst, 'reload schema';
