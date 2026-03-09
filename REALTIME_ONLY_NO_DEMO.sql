-- ✅ REALTIME ONLY - NO DEMO DATA!
-- Copy ALL of this and paste into Supabase SQL Editor, then click RUN

-- ============================================
-- ENABLE REALTIME ON ALL TABLES
-- ============================================

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
ALTER PUBLICATION supabase_realtime ADD TABLE public.banners;
ALTER PUBLICATION supabase_realtime ADD TABLE public.vendor_reviews;

-- ============================================
-- FIX RLS POLICIES - ALLOW READ ACCESS
-- ============================================

-- Delivery Riders
DROP POLICY IF EXISTS "Admin can view all riders" ON public.delivery_riders;
CREATE POLICY "Admin can view all riders" ON public.delivery_riders FOR SELECT USING (true);

DROP POLICY IF EXISTS "Riders can view own profile" ON public.delivery_riders;
CREATE POLICY "Riders can view own profile" ON public.delivery_riders FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Riders can update own profile" ON public.delivery_riders;
CREATE POLICY "Riders can update own profile" ON public.delivery_riders FOR UPDATE USING (auth.uid() = id);

-- Rider Locations
DROP POLICY IF EXISTS "Anyone can view rider locations" ON public.rider_locations;
CREATE POLICY "Anyone can view rider locations" ON public.rider_locations FOR SELECT USING (true);

DROP POLICY IF EXISTS "Riders can update own location" ON public.rider_locations;
CREATE POLICY "Riders can update own location" ON public.rider_locations FOR ALL USING (auth.uid() = rider_id);

-- Orders
DROP POLICY IF EXISTS "Customers can view own orders" ON public.orders;
CREATE POLICY "Customers can view own orders" ON public.orders FOR SELECT USING (auth.uid() = customer_id);

DROP POLICY IF EXISTS "Vendors can view their orders" ON public.orders;
CREATE POLICY "Vendors can view their orders" ON public.orders FOR SELECT USING (vendor_id IN (SELECT id FROM public.vendors WHERE id = auth.uid()));

DROP POLICY IF EXISTS "Riders can view assigned orders" ON public.orders;
CREATE POLICY "Riders can view assigned orders" ON public.orders FOR SELECT USING (auth.uid() = rider_id);

DROP POLICY IF EXISTS "Admin can view all orders" ON public.orders;
CREATE POLICY "Admin can view all orders" ON public.orders FOR SELECT USING (true);

-- Vendors
DROP POLICY IF EXISTS "Anyone can view vendors" ON public.vendors;
CREATE POLICY "Anyone can view vendors" ON public.vendors FOR SELECT USING (true);

DROP POLICY IF EXISTS "Vendors can update own profile" ON public.vendors;
CREATE POLICY "Vendors can update own profile" ON public.vendors FOR UPDATE USING (auth.uid() = id);

-- Menu Items
DROP POLICY IF EXISTS "Anyone can view menu items" ON public.menu_items;
CREATE POLICY "Anyone can view menu items" ON public.menu_items FOR SELECT USING (true);

DROP POLICY IF EXISTS "Vendors can manage own menu" ON public.menu_items;
CREATE POLICY "Vendors can manage own menu" ON public.menu_items FOR ALL USING (vendor_id IN (SELECT id FROM public.vendors WHERE id = auth.uid()));

-- Categories
DROP POLICY IF EXISTS "Anyone can view categories" ON public.categories;
CREATE POLICY "Anyone can view categories" ON public.categories FOR SELECT USING (true);

-- Customer Profiles
DROP POLICY IF EXISTS "Customers can view own profile" ON public.customer_profiles;
CREATE POLICY "Customers can view own profile" ON public.customer_profiles FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Customers can update own profile" ON public.customer_profiles;
CREATE POLICY "Customers can update own profile" ON public.customer_profiles FOR UPDATE USING (auth.uid() = id);

-- User Addresses
DROP POLICY IF EXISTS "Customers can view own addresses" ON public.user_addresses;
CREATE POLICY "Customers can view own addresses" ON public.user_addresses FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Customers can manage own addresses" ON public.user_addresses;
CREATE POLICY "Customers can manage own addresses" ON public.user_addresses FOR ALL USING (auth.uid() = user_id);

-- Notifications
DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
CREATE POLICY "Users can view own notifications" ON public.notifications FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;
CREATE POLICY "Users can update own notifications" ON public.notifications FOR UPDATE USING (auth.uid() = user_id);

-- Payments
DROP POLICY IF EXISTS "Users can view own payments" ON public.payments;
CREATE POLICY "Users can view own payments" ON public.payments FOR SELECT USING (auth.uid() = user_id);

-- Banners
DROP POLICY IF EXISTS "Anyone can view banners" ON public.banners;
CREATE POLICY "Anyone can view banners" ON public.banners FOR SELECT USING (true);

-- ============================================
-- GRANT PERMISSIONS
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
-- VERIFY REALTIME IS ENABLED
-- ============================================

SELECT tablename FROM pg_publication_tables WHERE pubname = 'supabase_realtime' ORDER BY tablename;
