-- ==========================================================
-- DAY 1: USER ISOLATION + AUTH FIX
-- Goal: No user sees another user's data. Ever.
-- Run this FIRST. Do not proceed until isolation is verified.
-- ==========================================================

BEGIN;

-- 1. ADMIN BYPASS FUNCTION (Required by all policies below)
CREATE OR REPLACE FUNCTION public.is_admin_strict()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN (
    current_setting('request.jwt.claims', true)::json->>'email' = 'univfoods@gmail.com' OR
    auth.jwt()->>'email' = 'univfoods@gmail.com'
  );
EXCEPTION WHEN OTHERS THEN
  RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. ORDERS TABLE — ENSURE ALL IDENTITY COLUMNS EXIST
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='customer_id') THEN
    ALTER TABLE orders ADD COLUMN customer_id TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='vendor_id') THEN
    ALTER TABLE orders ADD COLUMN vendor_id TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='delivery_id') THEN
    ALTER TABLE orders ADD COLUMN delivery_id TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='rider_id') THEN
    ALTER TABLE orders ADD COLUMN rider_id TEXT;
  END IF;
END $$;

-- 3. ENABLE RLS ON ALL SENSITIVE TABLES
ALTER TABLE public.orders             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_addresses     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_profiles  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallets            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_favorites     ENABLE ROW LEVEL SECURITY;

-- 4. ORDERS — FULL ROLE-BASED ISOLATION
DROP POLICY IF EXISTS "RLS_Orders_Isolation_V1" ON public.orders;
CREATE POLICY "RLS_Orders_Isolation_V1" ON public.orders
FOR ALL USING (
  customer_id = auth.uid()::text                                                 -- Customer sees their orders
  OR vendor_id = auth.uid()::text                                                -- Vendor sees their orders
  OR vendor_id IN (SELECT id::text FROM vendors WHERE owner_id = auth.uid()::text) -- Vendor by owner_id
  OR delivery_id = auth.uid()::text                                              -- Delivery sees their orders
  OR rider_id = auth.uid()::text                                                 -- Rider sees their orders
  OR customer_id = (current_setting('request.jwt.claims', true)::json->>'sub')  -- Firebase UID fallback
  OR is_admin_strict()
);

-- 5. USER ADDRESSES — CUSTOMER ISOLATION
DROP POLICY IF EXISTS "RLS_Addresses_V1" ON public.user_addresses;
CREATE POLICY "RLS_Addresses_V1" ON public.user_addresses
FOR ALL USING (
  user_id = auth.uid()::text OR
  user_id = (current_setting('request.jwt.claims', true)::json->>'sub') OR
  is_admin_strict()
);

-- 6. CUSTOMER PROFILES — SELF ONLY
DROP POLICY IF EXISTS "RLS_Profiles_V1" ON public.customer_profiles;
CREATE POLICY "RLS_Profiles_V1" ON public.customer_profiles
FOR ALL USING (
  id = auth.uid()::text OR
  id = (current_setting('request.jwt.claims', true)::json->>'sub') OR
  is_admin_strict()
);

-- 7. NOTIFICATIONS — SELF ONLY
DROP POLICY IF EXISTS "RLS_Notifications_V1" ON public.notifications;
CREATE POLICY "RLS_Notifications_V1" ON public.notifications
FOR ALL USING (
  user_id = auth.uid()::text OR
  user_id = (current_setting('request.jwt.claims', true)::json->>'sub') OR
  is_admin_strict()
);

-- 8. WALLETS — SELF ONLY
DROP POLICY IF EXISTS "RLS_Wallets_V1" ON public.wallets;
CREATE POLICY "RLS_Wallets_V1" ON public.wallets
FOR ALL USING (
  user_id = auth.uid()::text OR
  user_id = (current_setting('request.jwt.claims', true)::json->>'sub') OR
  is_admin_strict()
);

-- 9. FAVORITES — SELF ONLY
DROP POLICY IF EXISTS "RLS_Favorites_V1" ON public.user_favorites;
CREATE POLICY "RLS_Favorites_V1" ON public.user_favorites
FOR ALL USING (
  user_id::text = auth.uid()::text OR
  user_id::text = (current_setting('request.jwt.claims', true)::json->>'sub') OR
  is_admin_strict()
);

-- 10. VENDORS + CATEGORIES = PUBLIC READ ONLY
ALTER TABLE public.vendors    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "RLS_Vendors_PublicRead" ON public.vendors;
CREATE POLICY "RLS_Vendors_PublicRead" ON public.vendors FOR SELECT USING (true);
DROP POLICY IF EXISTS "RLS_Categories_PublicRead" ON public.categories;
CREATE POLICY "RLS_Categories_PublicRead" ON public.categories FOR SELECT USING (true);

COMMIT;
NOTIFY pgrst, 'reload schema';
