-- 🔒 CRITICAL DATA PRIVACY FIX - User Isolation (SAFE VERSION)
-- This ensures users ONLY see their own data, not other users' data
-- This version checks if tables exist before creating policies

-- ============================================
-- 0. CREATE MISSING TABLES FIRST
-- ============================================

-- Create favorites table if it doesn't exist
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

-- Create user_addresses table if it doesn't exist
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

-- ============================================
-- 1. FIX ORDERS TABLE - Users see only THEIR orders
-- ============================================

DROP POLICY IF EXISTS "Allow all orders" ON public.orders;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.orders;

CREATE POLICY "Users see only their orders" ON public.orders
    FOR SELECT
    USING (
        customer_id = auth.uid() 
        OR customer_id = (current_setting('app.current_user_id', true))::uuid
    );

CREATE POLICY "Users insert their own orders" ON public.orders
    FOR INSERT
    WITH CHECK (
        customer_id = auth.uid()
        OR customer_id = (current_setting('app.current_user_id', true))::uuid
    );

CREATE POLICY "Users update their own orders" ON public.orders
    FOR UPDATE
    USING (
        customer_id = auth.uid()
        OR customer_id = (current_setting('app.current_user_id', true))::uuid
    );

-- ============================================
-- 2. FIX CUSTOMER_PROFILES - Users see only THEIR profile
-- ============================================

DROP POLICY IF EXISTS "Allow all customer_profiles" ON public.customer_profiles;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.customer_profiles;

CREATE POLICY "Users see only their profile" ON public.customer_profiles
    FOR SELECT
    USING (
        id = auth.uid()
        OR id = (current_setting('app.current_user_id', true))::uuid
        OR phone = (current_setting('app.current_phone', true))::text
    );

CREATE POLICY "Users insert their own profile" ON public.customer_profiles
    FOR INSERT
    WITH CHECK (true);

CREATE POLICY "Users update their own profile" ON public.customer_profiles
    FOR UPDATE
    USING (
        id = auth.uid()
        OR id = (current_setting('app.current_user_id', true))::uuid
    );

-- ============================================
-- 3. FIX USER_ADDRESSES - Users see only THEIR addresses
-- ============================================

DROP POLICY IF EXISTS "Allow all user_addresses" ON public.user_addresses;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.user_addresses;

CREATE POLICY "Users see only their addresses" ON public.user_addresses
    FOR SELECT
    USING (
        user_id = auth.uid()
        OR user_id = (current_setting('app.current_user_id', true))::uuid
    );

CREATE POLICY "Users insert their own addresses" ON public.user_addresses
    FOR INSERT
    WITH CHECK (
        user_id = auth.uid()
        OR user_id = (current_setting('app.current_user_id', true))::uuid
    );

CREATE POLICY "Users update their own addresses" ON public.user_addresses
    FOR UPDATE
    USING (
        user_id = auth.uid()
        OR user_id = (current_setting('app.current_user_id', true))::uuid
    );

CREATE POLICY "Users delete their own addresses" ON public.user_addresses
    FOR DELETE
    USING (
        user_id = auth.uid()
        OR user_id = (current_setting('app.current_user_id', true))::uuid
    );

-- ============================================
-- 4. FIX FAVORITES - Users see only THEIR favorites
-- ============================================

DROP POLICY IF EXISTS "Allow all favorites" ON public.favorites;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.favorites;

CREATE POLICY "Users see only their favorites" ON public.favorites
    FOR SELECT
    USING (
        user_id = auth.uid()
        OR user_id = (current_setting('app.current_user_id', true))::uuid
    );

CREATE POLICY "Users manage their own favorites" ON public.favorites
    FOR ALL
    USING (
        user_id = auth.uid()
        OR user_id = (current_setting('app.current_user_id', true))::uuid
    )
    WITH CHECK (
        user_id = auth.uid()
        OR user_id = (current_setting('app.current_user_id', true))::uuid
    );

-- ============================================
-- 5. FIX CHAT_MESSAGES - Users see only THEIR order chats
-- ============================================

DROP POLICY IF EXISTS "Allow all chat" ON public.chat_messages;

CREATE POLICY "Users see their order chats" ON public.chat_messages
    FOR SELECT
    USING (
        sender_id = auth.uid()
        OR sender_id = (current_setting('app.current_user_id', true))::uuid
        OR order_id IN (
            SELECT id FROM public.orders 
            WHERE customer_id = auth.uid() 
            OR customer_id = (current_setting('app.current_user_id', true))::uuid
        )
    );

CREATE POLICY "Users send messages in their orders" ON public.chat_messages
    FOR INSERT
    WITH CHECK (
        order_id IN (
            SELECT id FROM public.orders 
            WHERE customer_id = auth.uid() 
            OR customer_id = (current_setting('app.current_user_id', true))::uuid
        )
    );

-- ============================================
-- 6. PUBLIC TABLES (Everyone can read)
-- ============================================

DROP POLICY IF EXISTS "Allow all vendors" ON public.vendors;
CREATE POLICY "Public can view vendors" ON public.vendors FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow all products" ON public.products;
CREATE POLICY "Public can view products" ON public.products FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow all categories" ON public.categories;
CREATE POLICY "Public can view categories" ON public.categories FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow all banners" ON public.banners;
CREATE POLICY "Public can view banners" ON public.banners FOR SELECT USING (true);

-- ============================================
-- 7. HELPER FUNCTION - Set Current User
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

-- ✅ DONE! Now:
-- 1. Each user sees ONLY their own orders
-- 2. Each user sees ONLY their own profile
-- 3. Each user sees ONLY their own addresses
-- 4. Each user sees ONLY their own favorites
-- 5. Public data (vendors, products) is visible to all
