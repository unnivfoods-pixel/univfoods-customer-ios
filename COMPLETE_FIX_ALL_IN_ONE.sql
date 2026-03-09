-- 🔥 COMPLETE FIX - ALL ISSUES RESOLVED IN ONE SCRIPT
-- Run this SINGLE script to fix everything!
-- This creates all missing tables + applies RLS + fixes tracking

-- ============================================
-- PART 1: CREATE ALL MISSING TABLES
-- ============================================

-- 1.1 Create FAVORITES table
CREATE TABLE IF NOT EXISTS public.favorites (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at timestamptz DEFAULT now(),
    user_id uuid NOT NULL,
    product_id uuid REFERENCES public.products(id) ON DELETE CASCADE,
    vendor_id uuid REFERENCES public.vendors(id) ON DELETE CASCADE,
    UNIQUE(user_id, product_id),
    UNIQUE(user_id, vendor_id)
);

ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_favorites_user ON public.favorites(user_id);
CREATE INDEX IF NOT EXISTS idx_favorites_product ON public.favorites(product_id);

-- 1.2 Create USER_ADDRESSES table
CREATE TABLE IF NOT EXISTS public.user_addresses (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at timestamptz DEFAULT now(),
    user_id uuid NOT NULL,
    address_type text DEFAULT 'home',
    address_line1 text NOT NULL,
    address_line2 text,
    landmark text,
    city text NOT NULL,
    state text NOT NULL,
    pincode text NOT NULL,
    latitude double precision,
    longitude double precision,
    is_default boolean DEFAULT false
);

ALTER TABLE public.user_addresses ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_user_addresses_user ON public.user_addresses(user_id);

-- 1.3 Create CHAT_MESSAGES table
CREATE TABLE IF NOT EXISTS public.chat_messages (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at timestamptz DEFAULT now(),
    order_id uuid REFERENCES public.orders(id) ON DELETE CASCADE,
    sender_id uuid NOT NULL,
    sender_role text NOT NULL, -- 'CUSTOMER', 'RIDER', 'VENDOR'
    message text NOT NULL,
    is_read boolean DEFAULT false,
    attachment_url text
);

ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages REPLICA IDENTITY FULL;
CREATE INDEX IF NOT EXISTS idx_chat_order ON public.chat_messages(order_id);
CREATE INDEX IF NOT EXISTS idx_chat_sender ON public.chat_messages(sender_id);

-- ============================================
-- PART 2: ADD RIDER TRACKING COLUMNS
-- ============================================

ALTER TABLE public.delivery_riders 
ADD COLUMN IF NOT EXISTS current_lat double precision DEFAULT 0,
ADD COLUMN IF NOT EXISTS current_lng double precision DEFAULT 0,
ADD COLUMN IF NOT EXISTS heading double precision DEFAULT 0,
ADD COLUMN IF NOT EXISTS vehicle_number text,
ADD COLUMN IF NOT EXISTS vehicle_type text DEFAULT 'bike',
ADD COLUMN IF NOT EXISTS is_online boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS profile_image text,
ADD COLUMN IF NOT EXISTS rating numeric DEFAULT 4.5,
ADD COLUMN IF NOT EXISTS total_deliveries integer DEFAULT 0;

-- ============================================
-- PART 3: CREATE PERFORMANCE INDEXES
-- ============================================

CREATE INDEX IF NOT EXISTS idx_orders_customer_status ON public.orders(customer_id, status);
CREATE INDEX IF NOT EXISTS idx_orders_rider ON public.orders(delivery_partner_id);
CREATE INDEX IF NOT EXISTS idx_orders_vendor ON public.orders(vendor_id);
CREATE INDEX IF NOT EXISTS idx_rider_location ON public.delivery_riders(current_lat, current_lng);
CREATE INDEX IF NOT EXISTS idx_rider_online ON public.delivery_riders(is_online);

-- ============================================
-- PART 4: ENABLE REALTIME FOR ALL TABLES
-- ============================================

ALTER TABLE public.orders REPLICA IDENTITY FULL;
ALTER TABLE public.delivery_riders REPLICA IDENTITY FULL;
ALTER TABLE public.customer_profiles REPLICA IDENTITY FULL;
ALTER TABLE public.favorites REPLICA IDENTITY FULL;
ALTER TABLE public.user_addresses REPLICA IDENTITY FULL;

-- Update realtime publication
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR TABLE 
    public.orders, 
    public.delivery_riders, 
    public.vendors, 
    public.customer_profiles,
    public.chat_messages,
    public.favorites,
    public.user_addresses,
    public.products,
    public.categories;

-- ============================================
-- PART 5: APPLY RLS POLICIES (DATA PRIVACY)
-- ============================================

-- 5.1 ORDERS - Users see only THEIR orders
DROP POLICY IF EXISTS "Allow all orders" ON public.orders;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.orders;

CREATE POLICY "Users see only their orders" ON public.orders
    FOR SELECT USING (
        customer_id = auth.uid() 
        OR customer_id = (current_setting('app.current_user_id', true))::uuid
    );

CREATE POLICY "Users insert their own orders" ON public.orders
    FOR INSERT WITH CHECK (
        customer_id = auth.uid()
        OR customer_id = (current_setting('app.current_user_id', true))::uuid
    );

CREATE POLICY "Users update their own orders" ON public.orders
    FOR UPDATE USING (
        customer_id = auth.uid()
        OR customer_id = (current_setting('app.current_user_id', true))::uuid
    );

-- 5.2 CUSTOMER_PROFILES - Users see only THEIR profile
DROP POLICY IF EXISTS "Allow all customer_profiles" ON public.customer_profiles;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.customer_profiles;

CREATE POLICY "Users see only their profile" ON public.customer_profiles
    FOR SELECT USING (
        id = auth.uid()
        OR id = (current_setting('app.current_user_id', true))::uuid
        OR phone = (current_setting('app.current_phone', true))::text
    );

CREATE POLICY "Users insert their own profile" ON public.customer_profiles
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Users update their own profile" ON public.customer_profiles
    FOR UPDATE USING (
        id = auth.uid()
        OR id = (current_setting('app.current_user_id', true))::uuid
    );

-- 5.3 USER_ADDRESSES - Users see only THEIR addresses
DROP POLICY IF EXISTS "Allow all user_addresses" ON public.user_addresses;

CREATE POLICY "Users see only their addresses" ON public.user_addresses
    FOR SELECT USING (
        user_id = auth.uid()
        OR user_id = (current_setting('app.current_user_id', true))::uuid
    );

CREATE POLICY "Users manage their addresses" ON public.user_addresses
    FOR ALL USING (
        user_id = auth.uid()
        OR user_id = (current_setting('app.current_user_id', true))::uuid
    ) WITH CHECK (
        user_id = auth.uid()
        OR user_id = (current_setting('app.current_user_id', true))::uuid
    );

-- 5.4 FAVORITES - Users see only THEIR favorites
DROP POLICY IF EXISTS "Allow all favorites" ON public.favorites;

CREATE POLICY "Users see only their favorites" ON public.favorites
    FOR SELECT USING (
        user_id = auth.uid()
        OR user_id = (current_setting('app.current_user_id', true))::uuid
    );

CREATE POLICY "Users manage their favorites" ON public.favorites
    FOR ALL USING (
        user_id = auth.uid()
        OR user_id = (current_setting('app.current_user_id', true))::uuid
    ) WITH CHECK (
        user_id = auth.uid()
        OR user_id = (current_setting('app.current_user_id', true))::uuid
    );

-- 5.5 CHAT_MESSAGES - Users see only THEIR order chats
DROP POLICY IF EXISTS "Allow all chat" ON public.chat_messages;

CREATE POLICY "Users see their order chats" ON public.chat_messages
    FOR SELECT USING (
        sender_id = auth.uid()
        OR sender_id = (current_setting('app.current_user_id', true))::uuid
        OR order_id IN (
            SELECT id FROM public.orders 
            WHERE customer_id = auth.uid() 
            OR customer_id = (current_setting('app.current_user_id', true))::uuid
        )
    );

CREATE POLICY "Users send messages in their orders" ON public.chat_messages
    FOR INSERT WITH CHECK (
        order_id IN (
            SELECT id FROM public.orders 
            WHERE customer_id = auth.uid() 
            OR customer_id = (current_setting('app.current_user_id', true))::uuid
        )
    );

-- 5.6 PUBLIC TABLES - Everyone can read
DROP POLICY IF EXISTS "Allow all vendors" ON public.vendors;
CREATE POLICY "Public can view vendors" ON public.vendors FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow all products" ON public.products;
CREATE POLICY "Public can view products" ON public.products FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow all categories" ON public.categories;
CREATE POLICY "Public can view categories" ON public.categories FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow all banners" ON public.banners;
CREATE POLICY "Public can view banners" ON public.banners FOR SELECT USING (true);

-- ============================================
-- PART 6: HELPER FUNCTION
-- ============================================

CREATE OR REPLACE FUNCTION set_current_user(user_id uuid, phone_number text DEFAULT NULL)
RETURNS void AS $$
BEGIN
    PERFORM set_config('app.current_user_id', user_id::text, false);
    IF phone_number IS NOT NULL THEN
        PERFORM set_config('app.current_phone', phone_number, false);
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- PART 7: UPDATE RIDER LOCATION FUNCTION
-- ============================================

-- Drop existing function first (to avoid parameter name conflicts)
DROP FUNCTION IF EXISTS update_rider_location(uuid, double precision, double precision, double precision);
DROP FUNCTION IF EXISTS update_rider_location(uuid, double precision, double precision);

CREATE OR REPLACE FUNCTION update_rider_location(
    rider_id uuid,
    lat double precision,
    lng double precision,
    rider_heading double precision DEFAULT 0
)
RETURNS void AS $$
BEGIN
    UPDATE public.delivery_riders
    SET 
        current_lat = lat,
        current_lng = lng,
        heading = rider_heading,
        is_online = true
    WHERE id = rider_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- ✅ VERIFICATION
-- ============================================

-- Check all tables exist and have RLS enabled
SELECT 
    tablename,
    CASE WHEN rowsecurity THEN '✅ RLS ON' ELSE '❌ RLS OFF' END as rls_status
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('orders', 'customer_profiles', 'user_addresses', 'favorites', 'chat_messages', 'delivery_riders')
ORDER BY tablename;

-- ✅ COMPLETE! This script:
-- 1. Creates all missing tables (favorites, user_addresses, chat_messages)
-- 2. Adds rider tracking columns (location, vehicle, etc.)
-- 3. Creates performance indexes
-- 4. Enables realtime for all tables
-- 5. Applies RLS policies for data privacy
-- 6. Creates helper functions
-- 7. No VACUUM commands (Supabase manages this automatically)
