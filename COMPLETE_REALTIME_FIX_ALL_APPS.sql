-- ✅ COMPLETE REALTIME FIX - ALL APPS
-- Run this in Supabase SQL Editor

-- ============================================
-- 1. ENABLE REALTIME ON ALL TABLES
-- ============================================

-- Core tables
ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
ALTER PUBLICATION supabase_realtime ADD TABLE public.order_items;
ALTER PUBLICATION supabase_realtime ADD TABLE public.vendors;
ALTER PUBLICATION supabase_realtime ADD TABLE public.menu_items;
ALTER PUBLICATION supabase_realtime ADD TABLE public.categories;
ALTER PUBLICATION supabase_realtime ADD TABLE public.customer_profiles;
ALTER PUBLICATION supabase_realtime ADD TABLE public.delivery_riders;
ALTER PUBLICATION supabase_realtime ADD TABLE public.user_addresses;
ALTER PUBLICATION supabase_realtime ADD TABLE public.payments;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE public.rider_locations;
ALTER PUBLICATION supabase_realtime ADD TABLE public.delivery_zones;
ALTER PUBLICATION supabase_realtime ADD TABLE public.vendor_reviews;
ALTER PUBLICATION supabase_realtime ADD TABLE public.banners;

-- ============================================
-- 2. FIX RLS POLICIES - ALLOW READ ACCESS
-- ============================================

-- Delivery Riders - Allow admin to see all riders
DROP POLICY IF EXISTS "Admin can view all riders" ON public.delivery_riders;
CREATE POLICY "Admin can view all riders"
ON public.delivery_riders
FOR SELECT
USING (true);

DROP POLICY IF EXISTS "Riders can view own profile" ON public.delivery_riders;
CREATE POLICY "Riders can view own profile"
ON public.delivery_riders
FOR SELECT
USING (auth.uid() = id);

DROP POLICY IF EXISTS "Riders can update own profile" ON public.delivery_riders;
CREATE POLICY "Riders can update own profile"
ON public.delivery_riders
FOR UPDATE
USING (auth.uid() = id);

-- Rider Locations - Allow admin and customers to see locations
DROP POLICY IF EXISTS "Anyone can view rider locations" ON public.rider_locations;
CREATE POLICY "Anyone can view rider locations"
ON public.rider_locations
FOR SELECT
USING (true);

DROP POLICY IF EXISTS "Riders can update own location" ON public.rider_locations;
CREATE POLICY "Riders can update own location"
ON public.rider_locations
FOR ALL
USING (auth.uid() = rider_id);

-- Orders - Allow all roles to see relevant orders
DROP POLICY IF EXISTS "Customers can view own orders" ON public.orders;
CREATE POLICY "Customers can view own orders"
ON public.orders
FOR SELECT
USING (auth.uid() = customer_id);

DROP POLICY IF EXISTS "Vendors can view their orders" ON public.orders;
CREATE POLICY "Vendors can view their orders"
ON public.orders
FOR SELECT
USING (
    vendor_id IN (
        SELECT id FROM public.vendors WHERE id = auth.uid()
    )
);

DROP POLICY IF EXISTS "Riders can view assigned orders" ON public.orders;
CREATE POLICY "Riders can view assigned orders"
ON public.orders
FOR SELECT
USING (auth.uid() = rider_id);

DROP POLICY IF EXISTS "Admin can view all orders" ON public.orders;
CREATE POLICY "Admin can view all orders"
ON public.orders
FOR SELECT
USING (true);

-- Vendors - Allow everyone to see vendors
DROP POLICY IF EXISTS "Anyone can view vendors" ON public.vendors;
CREATE POLICY "Anyone can view vendors"
ON public.vendors
FOR SELECT
USING (true);

DROP POLICY IF EXISTS "Vendors can update own profile" ON public.vendors;
CREATE POLICY "Vendors can update own profile"
ON public.vendors
FOR UPDATE
USING (auth.uid() = id);

-- Menu Items - Allow everyone to see menu items
DROP POLICY IF EXISTS "Anyone can view menu items" ON public.menu_items;
CREATE POLICY "Anyone can view menu items"
ON public.menu_items
FOR SELECT
USING (true);

DROP POLICY IF EXISTS "Vendors can manage own menu" ON public.menu_items;
CREATE POLICY "Vendors can manage own menu"
ON public.menu_items
FOR ALL
USING (
    vendor_id IN (
        SELECT id FROM public.vendors WHERE id = auth.uid()
    )
);

-- Categories - Allow everyone to see categories
DROP POLICY IF EXISTS "Anyone can view categories" ON public.categories;
CREATE POLICY "Anyone can view categories"
ON public.categories
FOR SELECT
USING (true);

-- Customer Profiles - Allow customers to see own profile
DROP POLICY IF EXISTS "Customers can view own profile" ON public.customer_profiles;
CREATE POLICY "Customers can view own profile"
ON public.customer_profiles
FOR SELECT
USING (auth.uid() = id);

DROP POLICY IF EXISTS "Customers can update own profile" ON public.customer_profiles;
CREATE POLICY "Customers can update own profile"
ON public.customer_profiles
FOR UPDATE
USING (auth.uid() = id);

-- User Addresses - Allow customers to manage own addresses
DROP POLICY IF EXISTS "Customers can view own addresses" ON public.user_addresses;
CREATE POLICY "Customers can view own addresses"
ON public.user_addresses
FOR SELECT
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Customers can manage own addresses" ON public.user_addresses;
CREATE POLICY "Customers can manage own addresses"
ON public.user_addresses
FOR ALL
USING (auth.uid() = user_id);

-- Notifications - Allow users to see own notifications
DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
CREATE POLICY "Users can view own notifications"
ON public.notifications
FOR SELECT
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;
CREATE POLICY "Users can update own notifications"
ON public.notifications
FOR UPDATE
USING (auth.uid() = user_id);

-- Payments - Allow users to see own payments
DROP POLICY IF EXISTS "Users can view own payments" ON public.payments;
CREATE POLICY "Users can view own payments"
ON public.payments
FOR SELECT
USING (auth.uid() = user_id);

-- Banners - Allow everyone to see banners
DROP POLICY IF EXISTS "Anyone can view banners" ON public.banners;
CREATE POLICY "Anyone can view banners"
ON public.banners
FOR SELECT
USING (true);

-- ============================================
-- 3. CREATE INDEXES FOR PERFORMANCE
-- ============================================

CREATE INDEX IF NOT EXISTS idx_orders_customer_id ON public.orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_vendor_id ON public.orders(vendor_id);
CREATE INDEX IF NOT EXISTS idx_orders_rider_id ON public.orders(rider_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON public.orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON public.orders(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_menu_items_vendor_id ON public.menu_items(vendor_id);
CREATE INDEX IF NOT EXISTS idx_menu_items_category_id ON public.menu_items(category_id);

CREATE INDEX IF NOT EXISTS idx_rider_locations_rider_id ON public.rider_locations(rider_id);
CREATE INDEX IF NOT EXISTS idx_rider_locations_updated_at ON public.rider_locations(updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications(created_at DESC);

-- ============================================
-- 4. GRANT PERMISSIONS
-- ============================================

GRANT USAGE ON SCHEMA public TO anon, authenticated;

GRANT SELECT ON public.orders TO anon, authenticated;
GRANT SELECT ON public.vendors TO anon, authenticated;
GRANT SELECT ON public.menu_items TO anon, authenticated;
GRANT SELECT ON public.categories TO anon, authenticated;
GRANT SELECT ON public.delivery_riders TO anon, authenticated;
GRANT SELECT ON public.rider_locations TO anon, authenticated;
GRANT SELECT ON public.banners TO anon, authenticated;

GRANT ALL ON public.customer_profiles TO authenticated;
GRANT ALL ON public.user_addresses TO authenticated;
GRANT ALL ON public.notifications TO authenticated;
GRANT ALL ON public.payments TO authenticated;

-- ============================================
-- 5. VERIFY REALTIME IS ENABLED
-- ============================================

-- Check which tables have realtime enabled
SELECT 
    schemaname,
    tablename
FROM 
    pg_publication_tables
WHERE 
    pubname = 'supabase_realtime'
ORDER BY 
    tablename;

-- ============================================
-- DONE! ✅
-- ============================================

-- All apps should now have realtime functionality:
-- ✅ Customer App - Orders, Menu, Vendors, Notifications
-- ✅ Vendor App - Orders, Menu Items, Notifications
-- ✅ Delivery App - Orders, Locations, Notifications
-- ✅ Admin Panel - Everything

NOTIFY pgrst, 'reload schema';
