-- 🌍 THE LOCATION-CONTROLLED FUTURE (V1.1)
-- 🧠 "IDENTITY & LOCATION SYNC"
-- Purpose: Total removal of demo logic, enforcing strict GPS validation, and ensuring Admin Panel compatibility.

BEGIN;

-- ==========================================================
-- 🛠 0. CLEANUP LEGACY & CONFLICTS
-- ==========================================================

DO $$ 
BEGIN
    -- 0. CLEANUP LEGACY BROKEN TRIGGERS
    DROP FUNCTION IF EXISTS public.on_order_status_change() CASCADE;
    DROP FUNCTION IF EXISTS public.sync_rider_mission_state() CASCADE;
    
    -- 1. ROBUST CLEAN SWEEP (Handles Table/View type conflicts)
    -- This block detects if the object is a TABLE or a VIEW and drops it safely.
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'delivery_riders') THEN
        IF (SELECT table_type FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'delivery_riders') = 'VIEW' THEN
            DROP VIEW public.delivery_riders CASCADE;
        ELSE
            DROP TABLE public.delivery_riders CASCADE;
        END IF;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'customer_profiles') THEN
        IF (SELECT table_type FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'customer_profiles') = 'VIEW' THEN
            DROP VIEW public.customer_profiles CASCADE;
        ELSE
            DROP TABLE public.customer_profiles CASCADE;
        END IF;
    END IF;

    DROP VIEW IF EXISTS public.order_details_v3 CASCADE;
    DROP VIEW IF EXISTS public.order_tracking_details_v1 CASCADE;

    -- 2. SAFE COLUMN RENAMING PROTOCOL (Always target 'id' as PK)
    -- Vendors
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'vendors' AND column_name = 'vendor_id') THEN
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'vendors' AND column_name = 'id') THEN
            ALTER TABLE public.vendors DROP COLUMN id;
        END IF;
        ALTER TABLE public.vendors RENAME COLUMN vendor_id TO id;
    END IF;

    -- Delivery Partners
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'delivery_partners' AND column_name = 'delivery_id') THEN
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'delivery_partners' AND column_name = 'id') THEN
            ALTER TABLE public.delivery_partners DROP COLUMN id;
        END IF;
        ALTER TABLE public.delivery_partners RENAME COLUMN delivery_id TO id;
    END IF;

    -- Products
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'products' AND column_name = 'product_id') THEN
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'products' AND column_name = 'id') THEN
            ALTER TABLE public.products DROP COLUMN id;
        END IF;
        ALTER TABLE public.products RENAME COLUMN product_id TO id;
    END IF;

    -- Orders
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'orders' AND column_name = 'order_id') THEN
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'orders' AND column_name = 'id') THEN
            ALTER TABLE public.orders DROP COLUMN id;
        END IF;
        ALTER TABLE public.orders RENAME COLUMN order_id TO id;
    END IF;

END $$;

-- ==========================================================
-- 🛠 1. CORE TABLES (ENFORCING SCHEMAS)
-- ==========================================================

-- 1️⃣ USERS
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT DEFAULT 'customer',
    full_name TEXT,
    phone TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'customer';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS full_name TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;
ALTER TABLE public.users REPLICA IDENTITY FULL;

-- 2️⃣ VENDORS
CREATE TABLE IF NOT EXISTS public.vendors (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT, -- Display Name
    shop_name TEXT, -- Logic Name
    address TEXT,
    phone TEXT,
    manager TEXT,
    cuisine_type TEXT DEFAULT 'Indian',
    open_time TEXT DEFAULT '09:00',
    close_time TEXT DEFAULT '22:00',
    banner_url TEXT,
    is_pure_veg BOOLEAN DEFAULT FALSE,
    has_offers BOOLEAN DEFAULT FALSE,
    lat DOUBLE PRECISION NOT NULL DEFAULT 9.5100,
    lng DOUBLE PRECISION NOT NULL DEFAULT 77.6300,
    radius_km DOUBLE PRECISION DEFAULT 15.0,
    status TEXT DEFAULT 'ONLINE',
    is_open BOOLEAN DEFAULT FALSE,
    is_verified BOOLEAN DEFAULT FALSE,
    rating DOUBLE PRECISION DEFAULT 5.0,
    created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS name TEXT;
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS shop_name TEXT;
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS address TEXT;
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'ONLINE';
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS is_open BOOLEAN DEFAULT FALSE;
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT FALSE;
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS rating DOUBLE PRECISION DEFAULT 5.0;
ALTER TABLE public.vendors REPLICA IDENTITY FULL;

-- 3️⃣ DELIVERY_PARTNERS
CREATE TABLE IF NOT EXISTS public.delivery_partners (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT,
    phone TEXT,
    rating DOUBLE PRECISION DEFAULT 5.0,
    status TEXT DEFAULT 'Online',
    current_lat DOUBLE PRECISION,
    current_lng DOUBLE PRECISION,
    is_online BOOLEAN DEFAULT FALSE,
    is_available BOOLEAN DEFAULT TRUE,
    vehicle_type TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.delivery_partners ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'Online';
ALTER TABLE public.delivery_partners ADD COLUMN IF NOT EXISTS rating DOUBLE PRECISION DEFAULT 5.0;
ALTER TABLE public.delivery_partners REPLICA IDENTITY FULL;

-- 4️⃣ ORDERS
CREATE TABLE IF NOT EXISTS public.orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID REFERENCES auth.users(id),
    vendor_id UUID REFERENCES public.vendors(id),
    delivery_id UUID REFERENCES public.delivery_partners(id),
    delivery_address_lat DOUBLE PRECISION NOT NULL DEFAULT 9.5100,
    delivery_address_lng DOUBLE PRECISION NOT NULL DEFAULT 77.6300,
    status TEXT DEFAULT 'PLACED',
    total DOUBLE PRECISION, -- Legacy/Admin compatibility
    total_amount DOUBLE PRECISION,
    items JSONB DEFAULT '[]',
    payment_status TEXT DEFAULT 'PENDING',
    payment_type TEXT DEFAULT 'UPI',
    otp TEXT,
    placed_at TIMESTAMPTZ DEFAULT now(),
    accepted_at TIMESTAMPTZ,
    pickup_time TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS total DOUBLE PRECISION;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS total_amount DOUBLE PRECISION;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'PLACED';
ALTER TABLE public.orders REPLICA IDENTITY FULL;

-- 5️⃣ PRODUCTS
CREATE TABLE IF NOT EXISTS public.products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_id UUID REFERENCES public.vendors(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    price DOUBLE PRECISION NOT NULL,
    is_available BOOLEAN DEFAULT TRUE
);
ALTER TABLE public.products REPLICA IDENTITY FULL;

-- ==========================================================
-- 🌍 2. LOGIC & VIEWS
-- ==========================================================

-- 1️⃣ NEARBY VENDORS
DROP FUNCTION IF EXISTS public.get_nearby_vendors_v4(DOUBLE PRECISION, DOUBLE PRECISION);
CREATE OR REPLACE FUNCTION public.get_nearby_vendors_v4(
    p_customer_lat DOUBLE PRECISION,
    p_customer_lng DOUBLE PRECISION
)
RETURNS TABLE (
    id UUID,
    name TEXT,
    lat DOUBLE PRECISION,
    lng DOUBLE PRECISION,
    distance_km DOUBLE PRECISION,
    radius_km DOUBLE PRECISION,
    is_open BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        v.id,
        COALESCE(v.name, v.shop_name) as name,
        v.lat,
        v.lng,
        (6371 * acos(cos(radians(p_customer_lat)) * cos(radians(v.lat)) * cos(radians(v.lng) - radians(p_customer_lng)) + sin(radians(p_customer_lat)) * sin(radians(v.lat)))) AS distance_km,
        v.radius_km,
        v.is_open
    FROM public.vendors v
    WHERE v.is_verified = TRUE
    AND (6371 * acos(cos(radians(p_customer_lat)) * cos(radians(v.lat)) * cos(radians(v.lng) - radians(p_customer_lng)) + sin(radians(p_customer_lat)) * sin(radians(v.lat)))) <= v.radius_km
    ORDER BY distance_km ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2️⃣ COMPATIBILITY VIEWS
CREATE OR REPLACE VIEW public.delivery_riders AS 
SELECT id, name, phone, rating, status, is_online, is_available, current_lat, current_lng, created_at
FROM public.delivery_partners;

CREATE OR REPLACE VIEW public.customer_profiles AS 
SELECT id, full_name, phone, created_at
FROM public.users;

CREATE OR REPLACE VIEW public.order_tracking_details_v1 AS
SELECT 
    o.id as order_id,
    o.status,
    o.total,
    o.total_amount,
    v.shop_name as vendor_name,
    v.lat as vendor_lat,
    v.lng as vendor_lng,
    dp.name as rider_name,
    dp.current_lat as rider_lat,
    dp.current_lng as rider_lng
FROM public.orders o
JOIN public.vendors v ON o.vendor_id = v.id
LEFT JOIN public.delivery_partners dp ON o.delivery_id = dp.id;

-- ==========================================================
-- ==========================================================
-- 🎁 3. CLEANUP & FINAL SYNC
-- ==========================================================
-- This block removes any "Demo" trash added by previous script versions
-- while ensuring your REAL data stays active.

DO $$
BEGIN
    -- 1. Remove Demo Vendors (Added by mistake in previous versions)
    DELETE FROM public.vendors 
    WHERE shop_name IN ('Srivilliputhur Special Curry', 'New Curry Shop', 'Srivilliputhur Digital Node')
    OR name IN ('Srivilliputhur Special Curry', 'New Curry Shop');

    -- 2. Ensure existing REAL users are at least 'active'
    UPDATE public.users SET is_active = TRUE WHERE is_active IS FALSE;
    
    -- 3. Sync 'name' with 'shop_name' for your real vendors if it's missing
    UPDATE public.vendors SET name = shop_name WHERE name IS NULL;
END $$;

-- Enable Realtime
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

COMMIT;
