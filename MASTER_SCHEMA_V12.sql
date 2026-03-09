-- 🏆 MASTER SYSTEM ARCHITECTURE (V12.0)
-- 🧠 THE GLOBAL HARMONY PROTOCOL
-- Purpose: Unified Schema for Customer, Vendor, Delivery, Admin, and Landing.

BEGIN;

-- ==========================================================
-- 🛠 0. SCHEMA REPAIR (Fixing Constraints)
-- ==========================================================
-- Remove unique constraint on owner_id to allow Demo/Multi-owned restaurants
ALTER TABLE public.vendors DROP CONSTRAINT IF EXISTS vendors_owner_id_key;
ALTER TABLE public.vendors DROP CONSTRAINT IF EXISTS unique_vendor_owner;

-- ==========================================================
-- 👤 1. USERS & PROFILES MODULE
-- ==========================================================

CREATE TABLE IF NOT EXISTS public.customer_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT,
    phone TEXT UNIQUE,
    email TEXT UNIQUE,
    avatar_url TEXT,
    default_lat DOUBLE PRECISION,
    default_lng DOUBLE PRECISION,
    default_address TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.delivery_riders (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT,
    phone TEXT UNIQUE,
    vehicle_type TEXT,
    vehicle_number TEXT,
    status TEXT DEFAULT 'OFFLINE', -- OFFLINE, ONLINE, BUSY
    is_approved BOOLEAN DEFAULT FALSE,
    current_lat DOUBLE PRECISION,
    current_lng DOUBLE PRECISION,
    last_gps_update TIMESTAMPTZ,
    active_order_id UUID,
    cod_debt DOUBLE PRECISION DEFAULT 0,
    earnings_total DOUBLE PRECISION DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ==========================================================
-- 🍽 2. RESTAURANTS & MENU MODULE
-- ==========================================================

CREATE TABLE IF NOT EXISTS public.vendors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID REFERENCES auth.users(id),
    name TEXT NOT NULL,
    email TEXT,
    phone TEXT,
    address TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    status TEXT DEFAULT 'OFFLINE', -- ONLINE, OFFLINE
    is_busy BOOLEAN DEFAULT FALSE,
    is_approved BOOLEAN DEFAULT FALSE,
    approval_status TEXT DEFAULT 'PENDING',
    delivery_radius_km DOUBLE PRECISION DEFAULT 15.0,
    commission_rate DOUBLE PRECISION DEFAULT 10.0,
    cuisine_type TEXT,
    rating NUMERIC DEFAULT 5.0,
    image_url TEXT,
    banner_url TEXT,
    is_pure_veg BOOLEAN DEFAULT FALSE,
    has_offers BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Vendor Schema Guards
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS owner_id UUID REFERENCES auth.users(id);
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'OFFLINE';
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS is_approved BOOLEAN DEFAULT FALSE;
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS approval_status TEXT DEFAULT 'PENDING';
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS delivery_radius_km DOUBLE PRECISION DEFAULT 15.0;
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS image_url TEXT;
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS banner_url TEXT;

CREATE TABLE IF NOT EXISTS public.categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    image_url TEXT,
    priority INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS public.products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_id UUID REFERENCES public.vendors(id) ON DELETE CASCADE,
    category_id UUID REFERENCES public.categories(id),
    name TEXT NOT NULL,
    description TEXT,
    price DOUBLE PRECISION NOT NULL,
    image_url TEXT,
    is_available BOOLEAN DEFAULT TRUE,
    is_veg BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Schema Integrity Guards: Add missing columns to existing tables
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS category_id UUID REFERENCES public.categories(id);
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS image_url TEXT;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS is_available BOOLEAN DEFAULT TRUE;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS is_veg BOOLEAN DEFAULT TRUE;

-- ==========================================================
-- 📦 3. ORDERS & TRACKING MODULE
-- ==========================================================

CREATE TABLE IF NOT EXISTS public.orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID REFERENCES auth.users(id),
    vendor_id UUID REFERENCES public.vendors(id),
    rider_id UUID REFERENCES public.delivery_riders(id),
    items JSONB, -- [ {product_id, name, qty, price} ]
    total DOUBLE PRECISION NOT NULL,
    status TEXT DEFAULT 'placed', -- placed, accepted, preparing, ready, picked_up, on_the_way, delivered, cancelled, rejected
    payment_method TEXT DEFAULT 'COD', -- COD, ONLINE
    payment_status TEXT DEFAULT 'PENDING', -- PENDING, PAID, REFUNDED
    address TEXT,
    delivery_lat DOUBLE PRECISION,
    delivery_lng DOUBLE PRECISION,
    pickup_lat DOUBLE PRECISION,
    pickup_lng DOUBLE PRECISION,
    pickup_otp TEXT,
    delivery_otp TEXT,
    cooking_instructions TEXT,
    rejection_reason TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    delivered_at TIMESTAMPTZ
);

-- Order Schema Guards
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS rider_id UUID REFERENCES public.delivery_riders(id);
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT 'COD';
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_lat DOUBLE PRECISION;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_lng DOUBLE PRECISION;

CREATE TABLE IF NOT EXISTS public.order_tracking (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES public.orders(id) ON DELETE CASCADE,
    rider_id UUID REFERENCES public.delivery_riders(id),
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    heading DOUBLE PRECISION,
    speed DOUBLE PRECISION,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ==========================================================
-- 💰 4. PAYMENTS & WALLET MODULE
-- ==========================================================

CREATE TABLE IF NOT EXISTS public.wallets (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id),
    balance DOUBLE PRECISION DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.withdrawals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id),
    amount DOUBLE PRECISION NOT NULL,
    status TEXT DEFAULT 'PENDING', -- PENDING, APPROVED, REJECTED
    payment_details JSONB,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ==========================================================
-- 🔔 5. NOTIFICATIONS & SUPPORT MODULE
-- ==========================================================

CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id),
    title TEXT,
    message TEXT,
    event_type TEXT, -- ORDER_PLACED, ORDER_ACCEPTED, etc.
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES public.orders(id),
    sender_id UUID REFERENCES auth.users(id),
    message TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ==========================================================
-- 🏢 5.5 VIEWS (Unified Data Access)
-- ==========================================================

DROP VIEW IF EXISTS public.order_details_v3;
CREATE VIEW public.order_details_v3 AS
SELECT 
    o.*,
    jsonb_build_object(
        'id', v.id,
        'name', v.name,
        'address', v.address,
        'latitude', v.latitude,
        'longitude', v.longitude,
        'image_url', v.image_url
    ) as vendors,
    jsonb_build_object(
        'full_name', cp.full_name,
        'phone', cp.phone,
        'email', cp.email
    ) as customer_profiles
FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id = v.id
LEFT JOIN public.customer_profiles cp ON o.customer_id = cp.id;

GRANT SELECT ON public.order_details_v3 TO anon, authenticated;

-- ==========================================================
-- 🧠 6. LOCATION ENGINE & BOOTSTRAP (RPC)
-- ==========================================================

CREATE OR REPLACE FUNCTION public.get_unified_bootstrap_data(p_user_id TEXT, p_role TEXT)
RETURNS JSON AS $$
DECLARE
    v_profile JSON;
    v_active_orders JSON;
    v_wallet JSON;
    v_vendor_ids UUID[];
BEGIN
    -- 1. VENDOR BRANCH
    IF p_role = 'vendor' THEN
        SELECT array_agg(id) INTO v_vendor_ids FROM public.vendors WHERE owner_id::text = p_user_id;
        SELECT row_to_json(v) INTO v_profile FROM public.vendors WHERE id = ANY(v_vendor_ids) LIMIT 1;
        IF v_vendor_ids IS NOT NULL THEN
            SELECT json_agg(o) INTO v_active_orders FROM public.order_details_v3 o 
            WHERE o.vendor_id = ANY(v_vendor_ids)
            AND lower(o.status) NOT IN ('delivered', 'cancelled', 'rejected');
        END IF;

    -- 2. CUSTOMER BRANCH
    ELSIF p_role = 'customer' THEN
        SELECT row_to_json(p) INTO v_profile FROM public.customer_profiles p WHERE p.id::text = p_user_id;
        SELECT json_agg(o) INTO v_active_orders FROM public.order_details_v3 o 
        WHERE o.customer_id::text = p_user_id AND lower(o.status) NOT IN ('delivered', 'cancelled', 'rejected');
    
    -- 3. DELIVERY BRANCH
    ELSIF p_role = 'delivery' THEN
        SELECT row_to_json(r) INTO v_profile FROM public.delivery_riders r WHERE r.id::text = p_user_id;
        SELECT json_agg(o) INTO v_active_orders FROM public.order_details_v3 o 
        WHERE o.rider_id::text = p_user_id AND lower(o.status) NOT IN ('delivered', 'cancelled', 'rejected');
    END IF;

    -- 4. WALLET FETCH
    SELECT row_to_json(w) INTO v_wallet FROM public.wallets w WHERE w.user_id::text = p_user_id;

    RETURN json_build_object(
        'profile', COALESCE(v_profile, '{}'::json),
        'orders', COALESCE(v_active_orders, '[]'::json),
        'wallet', COALESCE(v_wallet, '{"balance": 0}'::json)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.get_nearby_vendors_v3(
    customer_lat DOUBLE PRECISION,
    customer_lng DOUBLE PRECISION,
    max_radius_km DOUBLE PRECISION DEFAULT 15.0
)
RETURNS TABLE (
    id UUID, name TEXT, address TEXT, latitude DOUBLE PRECISION, longitude DOUBLE PRECISION,
    status TEXT, distance_km DOUBLE PRECISION, rating NUMERIC, cuisine_type TEXT,
    image_url TEXT, banner_url TEXT, is_pure_veg BOOLEAN, has_offers BOOLEAN, is_busy BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        v.id, v.name, v.address, v.latitude, v.longitude, v.status,
        (6371 * acos(cos(radians(customer_lat)) * cos(radians(v.latitude)) * cos(radians(v.longitude) - radians(customer_lng)) + sin(radians(customer_lat)) * sin(radians(v.latitude)))) AS distance_km,
        v.rating, v.cuisine_type, v.image_url, v.banner_url, v.is_pure_veg, v.has_offers, v.is_busy
    FROM public.vendors v
    WHERE v.is_approved = TRUE
      AND (6371 * acos(cos(radians(customer_lat)) * cos(radians(v.latitude)) * cos(radians(v.longitude) - radians(customer_lng)) + sin(radians(customer_lat)) * sin(radians(v.latitude)))) <= LEAST(v.delivery_radius_km, max_radius_km)
    ORDER BY distance_km ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 🛡️ RIDER RADAR SYNC (The Heart of Realtime Tracking)
CREATE OR REPLACE FUNCTION public.update_rider_location_v3(
    p_order_id UUID,
    p_rider_id UUID,
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION,
    p_speed DOUBLE PRECISION,
    p_heading DOUBLE PRECISION
)
RETURNS VOID AS $$
BEGIN
    -- 1. Update Rider's Global Position
    UPDATE public.delivery_riders 
    SET 
        current_lat = p_lat,
        current_lng = p_lng,
        last_gps_update = now()
    WHERE id = p_rider_id;

    -- 2. Log Tracking History (For Customer to see moving bike)
    INSERT INTO public.order_tracking (order_id, rider_id, latitude, longitude, speed, heading)
    VALUES (p_order_id, p_rider_id, p_lat, p_lng, p_speed, p_heading);

    -- 3. Sync Last known pos to Order for fast rendering
    UPDATE public.orders
    SET 
        delivery_lat = p_lat, -- Syncing current pos to order to let consumer find it instantly
        delivery_lng = p_lng
    WHERE id = p_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==========================================================
-- 🔄 5. MASTER BOOTSTRAP UPGRADE (Unified Data Fetch)
-- ==========================================================
-- Version 15: Full History Fetching (No more disappearances)
CREATE OR REPLACE FUNCTION public.get_unified_bootstrap_data(p_user_id TEXT, p_role TEXT)
RETURNS JSON AS $$
DECLARE
    v_profile JSON;
    v_orders JSON;
    v_wallet JSON;
    v_addresses JSON;
    v_vendor_ids UUID[];
BEGIN
    -- 1. VENDOR BRANCH (Fetch Profile + ALL Orders + Wallet)
    IF p_role = 'vendor' THEN
        SELECT array_agg(id) INTO v_vendor_ids FROM public.vendors WHERE owner_id::text = p_user_id;
        SELECT row_to_json(v) INTO v_profile FROM public.vendors WHERE id = ANY(v_vendor_ids) LIMIT 1;
        IF v_vendor_ids IS NOT NULL THEN
            SELECT json_agg(o) INTO v_orders FROM public.order_details_v3 o 
            WHERE o.vendor_id = ANY(v_vendor_ids)
            ORDER BY o.created_at DESC;
        END IF;

    -- 2. CUSTOMER BRANCH (Fetch Profile + ALL Orders + Addresses + Wallet)
    ELSIF p_role = 'customer' THEN
        SELECT row_to_json(p) INTO v_profile FROM public.customer_profiles p WHERE p.id::text = p_user_id;
        SELECT json_agg(o) INTO v_orders FROM public.order_details_v3 o 
        WHERE o.customer_id::text = p_user_id
        ORDER BY o.created_at DESC;
        SELECT json_agg(a) INTO v_addresses FROM public.user_addresses a WHERE a.user_id = p_user_id;
    
    -- 3. DELIVERY BRANCH (Fetch Profile + ALL Assigned Orders + Wallet)
    ELSIF p_role = 'delivery' THEN
        SELECT row_to_json(r) INTO v_profile FROM public.delivery_riders r WHERE r.id::text = p_user_id;
        SELECT json_agg(o) INTO v_orders FROM public.order_details_v3 o 
        WHERE o.rider_id::text = p_user_id
        ORDER BY o.created_at DESC;
    END IF;

    -- 4. WALLET FETCH (Common)
    SELECT row_to_json(w) INTO v_wallet FROM public.wallets w WHERE w.user_id::text = p_user_id;

    RETURN json_build_object(
        'profile', COALESCE(v_profile, '{}'::json),
        'orders', COALESCE(v_orders, '[]'::json),
        'wallet', COALESCE(v_wallet, '{"balance": 0}'::json),
        'addresses', COALESCE(v_addresses, '[]'::json)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 🛡️ GUEST TO REAL USER MIGRATION (Crucial for Play Store submission)
-- Prevents "Vanishing Data" when a guest finally signs in
CREATE OR REPLACE FUNCTION public.migrate_guest_orders(p_guest_id TEXT, p_auth_id TEXT)
RETURNS VOID AS $$
BEGIN
    -- Move orders to the new real auth ID
    UPDATE public.orders 
    SET customer_id = p_auth_id::uuid 
    WHERE customer_id::text = p_guest_id;
    
    -- Move wallet balance if any
    UPDATE public.wallets 
    SET user_id = p_auth_id::uuid 
    WHERE user_id::text = p_guest_id;
    
    -- Merge profile data if necessary
    INSERT INTO public.customer_profiles (id, full_name, phone, email)
    SELECT p_auth_id::uuid, full_name, phone, email 
    FROM public.customer_profiles WHERE id::text = p_guest_id
    ON CONFLICT (id) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==========================================================
-- ⚡ 7. REALTIME ENABLEMENT
-- ==========================================================

ALTER TABLE public.orders REPLICA IDENTITY FULL;
ALTER TABLE public.order_tracking REPLICA IDENTITY FULL;
ALTER TABLE public.notifications REPLICA IDENTITY FULL;
ALTER TABLE public.chat_messages REPLICA IDENTITY FULL;
ALTER TABLE public.delivery_riders REPLICA IDENTITY FULL;

DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

-- ==========================================================
-- ==========================================================
-- � 8. NON-DESTRUCTIVE HARMONY (Restore Data)
-- ==========================================================

-- Ensure Categories exist before products
INSERT INTO public.categories (id, name, priority) VALUES 
('38aae661-371d-4a18-b0a4-95cc7ec5b495'::uuid, 'Curry & Meals', 1)
ON CONFLICT (id) DO NOTHING;

-- Fix Royal Curry House (Non-Destructive)
-- Primary identity used by Vendor App Demo
INSERT INTO public.vendors (
    id, name, status, owner_id, is_approved, approval_status, delivery_radius_km, latitude, longitude
) VALUES (
    '11111111-1111-1111-1111-111111111111'::uuid,
    'Royal Curry House', 'ONLINE',
    '00000000-0000-0000-0000-000000000001'::uuid, TRUE, 'APPROVED', 999.0, 9.5127, 77.6337
) ON CONFLICT (id) DO UPDATE SET 
    owner_id = EXCLUDED.owner_id, 
    status = 'ONLINE', 
    is_approved = TRUE,
    latitude = 9.5127,
    longitude = 77.6337;

-- Fix Curry Point (Identity Binding)
-- Ensuring "srivilliputhur curry points" is linked and active
INSERT INTO public.vendors (
    id, name, status, owner_id, is_approved, approval_status, delivery_radius_km, latitude, longitude
) VALUES (
    '8c07ffd1-1901-4f41-ab0f-c5adcfcf4f93'::uuid,
    'Curry Point', 'ONLINE',
    '00000000-0000-0000-0000-000000000001'::uuid, TRUE, 'APPROVED', 999.0, 9.5120, 77.6320
) ON CONFLICT (id) DO UPDATE SET 
    name = 'Curry Point',
    owner_id = EXCLUDED.owner_id, 
    status = 'ONLINE', 
    is_approved = TRUE,
    latitude = 9.5120,
    longitude = 77.6320;

-- 🍛 RESTORE MENU ITEMS FROM HISTORY
INSERT INTO public.products (id, vendor_id, category_id, name, price, is_available) VALUES
('c59712e0-346e-49bb-bb3c-3a6c08685991'::uuid, '11111111-1111-1111-1111-111111111111'::uuid, '38aae661-371d-4a18-b0a4-95cc7ec5b495'::uuid, '🍲 Sambar Curry', 25.0, TRUE),
('7625c889-c00b-4107-85bb-f0a789f6ad94'::uuid, '11111111-1111-1111-1111-111111111111'::uuid, '38aae661-371d-4a18-b0a4-95cc7ec5b495'::uuid, 'Chicken Biryani', 180.0, TRUE),
('e7c09781-eac0-477b-8139-31c022627ee2'::uuid, '11111111-1111-1111-1111-111111111111'::uuid, '38aae661-371d-4a18-b0a4-95cc7ec5b495'::uuid, 'Idli Set', 40.0, TRUE),
('28f7f5a0-50e6-47e3-b17b-e9dad137efee'::uuid, '11111111-1111-1111-1111-111111111111'::uuid, '38aae661-371d-4a18-b0a4-95cc7ec5b495'::uuid, 'Ghee Roast Special', 160.0, TRUE),
('75ad74d7-07e4-46ac-bbf8-28098a0e58f7'::uuid, '11111111-1111-1111-1111-111111111111'::uuid, '38aae661-371d-4a18-b0a4-95cc7ec5b495'::uuid, 'Masala Dosa', 60.0, TRUE)
ON CONFLICT (id) DO NOTHING;

COMMIT;
