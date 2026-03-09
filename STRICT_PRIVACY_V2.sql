-- ==========================================================
-- 🛡️ PRIVACY & IDENTITY ISOLATION PROTOCOL V2.0 🛡️
-- ==========================================================
-- This script enforces strictly Row Level Security (RLS) 
-- on all tables and ensures that data is isolated by user.

-- 1. Helper Function for Admin Bypass (UNIV Foods Gmail only)
CREATE OR REPLACE FUNCTION is_admin_strict() RETURNS BOOLEAN AS $$
BEGIN
  -- Check if JWT email is the admin email OR role is service_role
  RETURN (
    (current_setting('request.jwt.claims', true)::json->>'email' = 'univfoods@gmail.com') OR 
    (current_setting('role', true) = 'service_role')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. ENABLE RLS ON ALL SENSITIVE TABLES
ALTER TABLE IF EXISTS "orders" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "user_addresses" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "customer_profiles" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "user_favorites" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "notifications" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "wallets" ENABLE ROW LEVEL SECURITY;

-- 3. DROP OLD PERMISSIVE POLICIES
DO $$ 
BEGIN
    -- Orders
    DROP POLICY IF EXISTS "Users can only see their own orders" ON "orders";
    DROP POLICY IF EXISTS "Admin see all orders" ON "orders";
    
    -- Addresses
    DROP POLICY IF EXISTS "Users can only see their own addresses" ON "user_addresses";
    DROP POLICY IF EXISTS "Admin see all addresses" ON "user_addresses";
    
    -- Favorites
    DROP POLICY IF EXISTS "Users can only see their own favorites" ON "user_favorites";
    
    -- Profiles
    DROP POLICY IF EXISTS "Users can only see their own profiles" ON "customer_profiles";
END $$;

-- 4. CREATE STRICT ISOLATION POLICIES (Enforced V2)

-- 📦 ORDERS: Isolation by customer_id or user_id
CREATE POLICY "RLS_ORDER_ISOLATION_V2" ON "orders" 
    FOR ALL TO public 
    USING (
        (customer_id = auth.uid()::text) OR 
        (customer_id = current_setting('request.jwt.claims', true)::json->>'sub') OR 
        is_admin_strict()
    );

-- 📍 ADDRESSES: Isolation by user_id
CREATE POLICY "RLS_ADDRESS_ISOLATION_V2" ON "user_addresses" 
    FOR ALL TO public 
    USING (
        (user_id = auth.uid()::text) OR 
        (user_id = current_setting('request.jwt.claims', true)::json->>'sub') OR 
        is_admin_strict()
    );

-- ❤️ FAVORITES: Isolation by user_id
CREATE POLICY "RLS_FAVORITE_ISOLATION_V2" ON "user_favorites" 
    FOR ALL TO public 
    USING (
        (user_id = auth.uid()::text) OR 
        (user_id = current_setting('request.jwt.claims', true)::json->>'sub') OR 
        is_admin_strict()
    );

-- 👤 PROFILES: Isolation by id
CREATE POLICY "RLS_PROFILE_ISOLATION_V2" ON "customer_profiles" 
    FOR ALL TO public 
    USING (
        (id = auth.uid()::text) OR 
        (id = current_setting('request.jwt.claims', true)::json->>'sub') OR 
        is_admin_strict()
    );

-- 5. PUBLIC ACCESS (Vendors & Products must be viewable by everyone)
ALTER TABLE IF EXISTS "vendors" ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access to vendors" ON "vendors";
CREATE POLICY "Public access to vendors" ON "vendors" FOR SELECT TO public USING (true);

ALTER TABLE IF EXISTS "products" ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access to products" ON "products";
CREATE POLICY "Public access to products" ON "products" FOR SELECT TO public USING (true);

-- 6. GRANT PERMISSIONS
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon;
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;

-- ⚙️ RE-VERIFYING VIEWS FOR DATA INTEGRITY
-- Drop and recreate views to ensure they inherit RLS from base tables if defined correctly.
DROP VIEW IF EXISTS order_tracking_details_v1;
CREATE VIEW order_tracking_details_v1 AS 
SELECT 
  o.id as order_id,
  o.customer_id,
  o.vendor_id,
  v.name as vendor_name,
  v.image_url as vendor_image,
  o.total,
  o.status as order_status,
  o.created_at,
  o.items,
  o.rider_id,
  o.payment_method,
  o.delivery_address as address,
  o.cooking_instructions
FROM orders o
LEFT JOIN vendors v ON o.vendor_id = v.id;

NOTIFY pgrst, 'reload schema';
