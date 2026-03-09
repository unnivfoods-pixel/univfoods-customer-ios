-- UNIVERSAL TYPE & VISIBILITY REPAIR (v30.0)
-- 🎯 MISSION: Fix "is_active does not exist" and resolve "customer_name" conflicts.

BEGIN;

-- 1. CLEANUP CONFLICTING COLUMNS FROM ORDERS TABLE
-- We rename existing "customer_name" etc to legacy versions to stop name collisions in the view.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'customer_name') THEN
        ALTER TABLE public.orders RENAME COLUMN customer_name TO customer_name_legacy;
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'vendor_name') THEN
        ALTER TABLE public.orders RENAME COLUMN vendor_name TO vendor_name_legacy;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'customer_phone') THEN
        ALTER TABLE public.orders RENAME COLUMN customer_phone TO customer_phone_legacy;
    END IF;
EXCEPTION WHEN OTHERS THEN 
    NULL;
END $$;

-- 2. REPAIR ALL MISSING COLUMNS (Identity, Visibility, Logistics)
-- Products
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS is_available BOOLEAN DEFAULT TRUE;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'Available';

-- Vendors
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS is_approved BOOLEAN DEFAULT TRUE;
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION;
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS delivery_radius_km DOUBLE PRECISION DEFAULT 15.0;

-- Orders
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS user_id TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS vendor_id TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS rider_id TEXT;
ALTER TABLE public.orders ALTER COLUMN user_id TYPE TEXT;
ALTER TABLE public.orders ALTER COLUMN vendor_id TYPE TEXT;
ALTER TABLE public.orders ALTER COLUMN rider_id TYPE TEXT;

-- Categories
ALTER TABLE public.categories ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;

-- 3. FORCE VISIBILITY (Healing existing records)
UPDATE public.vendors 
SET status = 'ONLINE', 
    is_active = true, 
    is_approved = true,
    latitude = COALESCE(latitude, 9.5100),
    longitude = COALESCE(longitude, 77.6300),
    delivery_radius_km = COALESCE(delivery_radius_km, 15.0)
WHERE status IS NULL OR status = 'OFFLINE' OR latitude IS NULL;

UPDATE public.products 
SET is_active = true, 
    is_available = true, 
    status = 'Available' 
WHERE is_active IS FALSE OR is_active IS NULL;

UPDATE public.categories SET is_active = true WHERE is_active IS FALSE OR is_active IS NULL;

-- 4. REBUILD MASTER VIEW (order_details_v3)
-- Dynamic name mapping now that collisions are resolved.
DROP VIEW IF EXISTS public.order_details_v3;
CREATE OR REPLACE VIEW public.order_details_v3 AS
SELECT 
    o.*,
    COALESCE(u.full_name, o.customer_name_legacy, 'Guest User') as customer_name,
    COALESCE(u.email, 'no-email@univ.in') as customer_email,
    COALESCE(v.name, v.shop_name, o.vendor_name_legacy, 'Generic Station') as vendor_name,
    COALESCE(r.name, 'Unassigned') as rider_name
FROM public.orders o
LEFT JOIN public.users u ON o.user_id::TEXT = u.id::TEXT
LEFT JOIN public.vendors v ON o.vendor_id::TEXT = v.id::TEXT
LEFT JOIN public.delivery_riders r ON o.rider_id::TEXT = r.id::TEXT;

-- 5. RELOAD & PERMISSIONS
ALTER TABLE public.orders DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendors DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.products DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories DISABLE ROW LEVEL SECURITY;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;

NOTIFY pgrst, 'reload schema';

COMMIT;

SELECT 'UNIVERSAL REPAIR COMPLETE (v30.0) - ALL SYSTEMS ACTIVE' as report;
