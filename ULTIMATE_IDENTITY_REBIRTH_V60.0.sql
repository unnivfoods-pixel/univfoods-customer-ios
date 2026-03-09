-- ==========================================================
-- 🛡️ ULTIMATE IDENTITY REBIRTH (v60.1) - NUCLEAR EDITION
-- 🎯 MISSION: End the 22P02 "Data Format Mismatch" forever.
-- 🎯 STRATEGY: Migration from UUID to TEXT for ALL Identity columns (PK & FK).
-- This handles the incompatible types error (42804) by converting both sides of the link.
-- ==========================================================

BEGIN;

-- 1. DROP DEPENDENT VIEWS (They block column type changes)
DROP VIEW IF EXISTS public.order_details_v3 CASCADE;
DROP VIEW IF EXISTS public.order_details_v2 CASCADE;
DROP VIEW IF EXISTS public.order_details_v1 CASCADE;
DROP VIEW IF EXISTS public.order_tracking_details_v1 CASCADE;
DROP VIEW IF EXISTS public.vendor_details_v1 CASCADE;
DROP VIEW IF EXISTS public.rider_details_v1 CASCADE;

-- 2. NUCLEAR CONSTRAINT REMOVAL
-- We drop ALL foreign keys to allow type conversion without type-check errors.
DO $$ 
DECLARE 
    r RECORD;
BEGIN
    FOR r IN (SELECT constraint_name, table_name FROM information_schema.table_constraints WHERE constraint_type = 'FOREIGN KEY' AND table_schema = 'public') 
    LOOP
        EXECUTE 'ALTER TABLE public.' || quote_ident(r.table_name) || ' DROP CONSTRAINT IF EXISTS ' || quote_ident(r.constraint_name) || ' CASCADE';
    END LOOP;
END $$;

-- 3. ORDERS TABLE MIGRATION (The Hub)
DO $$ 
BEGIN
    -- Drop all constraints related to orders
    ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_pkey CASCADE;
    
    -- Convert columns to TEXT
    ALTER TABLE public.orders ALTER COLUMN id TYPE TEXT USING id::TEXT;
    ALTER TABLE public.orders ALTER COLUMN customer_id TYPE TEXT USING customer_id::TEXT;
    ALTER TABLE public.orders ALTER COLUMN vendor_id TYPE TEXT USING vendor_id::TEXT;
    ALTER TABLE public.orders ALTER COLUMN rider_id TYPE TEXT USING rider_id::TEXT;
    
    -- LOGISTICS SNAPSHOT COLUMNS (No more Demo Data!)
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_address TEXT;
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_lat DOUBLE PRECISION;
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_lng DOUBLE PRECISION;
    
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS vendor_lat DOUBLE PRECISION;
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS vendor_lng DOUBLE PRECISION;
    
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS rider_lat DOUBLE PRECISION;
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS rider_lng DOUBLE PRECISION;
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS rider_last_seen TIMESTAMPTZ;
    
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS estimated_arrival_time TEXT DEFAULT 'Calculating...';
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS assigned_at TIMESTAMPTZ;
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS pickup_time TIMESTAMPTZ;
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMPTZ;
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ;

    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS customer_name TEXT;
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS customer_phone TEXT;

    ALTER TABLE public.orders ADD PRIMARY KEY (id);
END $$;

-- 4. CUSTOMER PROFILES MIGRATION
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname = 'public' AND viewname = 'customer_profiles') THEN
        DROP VIEW public.customer_profiles CASCADE;
        CREATE TABLE public.customer_profiles (
            id TEXT PRIMARY KEY,
            full_name TEXT,
            phone TEXT,
            avatar_url TEXT,
            created_at TIMESTAMPTZ DEFAULT now()
        );
    ELSE
        ALTER TABLE public.customer_profiles DROP CONSTRAINT IF EXISTS customer_profiles_pkey CASCADE;
        ALTER TABLE public.customer_profiles ALTER COLUMN id TYPE TEXT USING id::TEXT;
        ALTER TABLE public.customer_profiles ADD PRIMARY KEY (id);
    END IF;
END $$;

-- 5. VENDORS TABLE MIGRATION (Self-Healing)
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname = 'public' AND viewname = 'vendors') THEN
        DROP VIEW public.vendors CASCADE;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'vendors') THEN
        CREATE TABLE public.vendors (
            id TEXT PRIMARY KEY,
            name TEXT,
            address TEXT,
            phone TEXT,
            image_url TEXT,
            latitude DOUBLE PRECISION,
            longitude DOUBLE PRECISION,
            owner_id TEXT,
            created_at TIMESTAMPTZ DEFAULT now()
        );
    ELSE
        ALTER TABLE public.vendors DROP CONSTRAINT IF EXISTS vendors_pkey CASCADE;
        ALTER TABLE public.vendors ALTER COLUMN id TYPE TEXT USING id::TEXT;
        ALTER TABLE public.vendors ALTER COLUMN owner_id TYPE TEXT USING owner_id::TEXT;
        ALTER TABLE public.vendors ADD PRIMARY KEY (id);
        
        -- Ensure all columns needed by view exist
        ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS address TEXT;
        ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS phone TEXT;
        ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS image_url TEXT;
        ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION;
        ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;
    END IF;
END $$;

-- 6. PRODUCTS TABLE MIGRATION
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'products') THEN
        ALTER TABLE public.products ALTER COLUMN id TYPE TEXT USING id::TEXT;
        ALTER TABLE public.products ALTER COLUMN vendor_id TYPE TEXT USING vendor_id::TEXT;
    END IF;
END $$;

-- 7. RIDERS TABLE MIGRATION (Self-Healing)
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname = 'public' AND viewname = 'delivery_riders') THEN
        DROP VIEW public.delivery_riders CASCADE;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'delivery_riders') THEN
        CREATE TABLE public.delivery_riders (
            id TEXT PRIMARY KEY,
            name TEXT,
            phone TEXT,
            vehicle_number TEXT,
            profile_image TEXT,
            rating NUMERIC DEFAULT 5.0,
            total_orders INTEGER DEFAULT 0,
            current_lat DOUBLE PRECISION,
            current_lng DOUBLE PRECISION,
            last_gps_update TIMESTAMPTZ,
            created_at TIMESTAMPTZ DEFAULT now()
        );
    ELSE
        ALTER TABLE public.delivery_riders DROP CONSTRAINT IF EXISTS delivery_riders_pkey CASCADE;
        ALTER TABLE public.delivery_riders ALTER COLUMN id TYPE TEXT USING id::TEXT;
        ALTER TABLE public.delivery_riders ADD PRIMARY KEY (id);
        
        -- Ensure all columns needed by view exist
        ALTER TABLE public.delivery_riders ADD COLUMN IF NOT EXISTS phone TEXT;
        ALTER TABLE public.delivery_riders ADD COLUMN IF NOT EXISTS vehicle_number TEXT;
        ALTER TABLE public.delivery_riders ADD COLUMN IF NOT EXISTS profile_image TEXT;
        ALTER TABLE public.delivery_riders ADD COLUMN IF NOT EXISTS rating NUMERIC DEFAULT 5.0;
        ALTER TABLE public.delivery_riders ADD COLUMN IF NOT EXISTS total_orders INTEGER DEFAULT 0;
        ALTER TABLE public.delivery_riders ADD COLUMN IF NOT EXISTS current_lat DOUBLE PRECISION;
        ALTER TABLE public.delivery_riders ADD COLUMN IF NOT EXISTS current_lng DOUBLE PRECISION;
        ALTER TABLE public.delivery_riders ADD COLUMN IF NOT EXISTS last_gps_update TIMESTAMPTZ;
    END IF;
END $$;

-- 8. THE TROUBLEMAKERS (Live Tracking, Messages, items)
DO $$ 
BEGIN
    -- Forceful drop of the specific constraint that's causing trouble
    -- This is a backup in case the loop in Step 2 missed it.
    EXECUTE 'ALTER TABLE IF EXISTS public.order_live_tracking DROP CONSTRAINT IF EXISTS order_live_tracking_order_id_fkey CASCADE';
    EXECUTE 'ALTER TABLE IF EXISTS public.order_live_tracking DROP CONSTRAINT IF EXISTS order_live_tracking_rider_id_fkey CASCADE';
    EXECUTE 'ALTER TABLE IF EXISTS public.order_messages DROP CONSTRAINT IF EXISTS order_messages_order_id_fkey CASCADE';

    -- Now proceed with type conversion
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'order_live_tracking') THEN
        ALTER TABLE public.order_live_tracking ALTER COLUMN order_id TYPE TEXT USING order_id::TEXT;
        ALTER TABLE public.order_live_tracking ALTER COLUMN rider_id TYPE TEXT USING rider_id::TEXT;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'order_messages') THEN
        ALTER TABLE public.order_messages ALTER COLUMN order_id TYPE TEXT USING order_id::TEXT;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'order_items') THEN
        ALTER TABLE public.order_items ALTER COLUMN order_id TYPE TEXT USING order_id::TEXT;
    END IF;
END $$;

-- 9. REBUILD THE TRUTH VIEW (v3) - FORCE RESET
DROP VIEW IF EXISTS public.order_details_v3 CASCADE;
CREATE VIEW public.order_details_v3 AS
SELECT 
    o.id as order_id,
    o.customer_id,
    o.vendor_id,
    o.rider_id,
    o.items,
    o.total,
    o.status,
    o.payment_method,
    o.payment_status,
    o.delivery_address,
    o.delivery_lat,
    o.delivery_lng,
    o.vendor_lat,
    o.vendor_lng,
    o.rider_lat,
    o.rider_lng,
    o.rider_last_seen,
    o.estimated_arrival_time,
    o.cooking_instructions,
    o.created_at,
    o.assigned_at,
    o.pickup_time,
    o.delivered_at,
    o.cancelled_at,
    v.name as vendor_name,
    v.address as vendor_address,
    v.phone as vendor_phone,
    v.image_url as vendor_image_url,
    v.owner_id as vendor_owner_id,
    COALESCE(NULLIF(cp.full_name, ''), NULLIF(o.customer_name, ''), 'Guest User') as customer_name,
    COALESCE(NULLIF(cp.phone, ''), NULLIF(o.customer_phone, ''), 'No Phone') as customer_phone,
    cp.avatar_url as customer_avatar,
    dr.name as rider_name,
    dr.phone as rider_phone,
    dr.vehicle_number as rider_vehicle,
    dr.profile_image as rider_avatar,
    dr.rating as rider_rating,
    dr.total_orders as rider_total_orders,
    CASE 
        WHEN o.status = 'placed' THEN 'Order Placed'
        WHEN o.status = 'accepted' THEN 'Rider Assigned'
        WHEN o.status = 'preparing' THEN 'Chef is Cooking'
        WHEN o.status = 'ready' THEN 'Ready for Pickup'
        WHEN o.status = 'picked_up' THEN 'Food Picked Up'
        WHEN o.status = 'on_the_way' THEN 'Out for Delivery'
        WHEN o.status = 'delivered' THEN 'Delivered'
        ELSE UPPER(o.status)
    END as status_display,
    CASE 
        WHEN o.status IN ('placed', 'accepted', 'RIDER_ASSIGNED') THEN 1
        WHEN o.status IN ('preparing', 'ready') THEN 2
        WHEN o.status = 'picked_up' THEN 3
        WHEN o.status = 'on_the_way' THEN 4
        WHEN o.status = 'delivered' THEN 5
        ELSE 1
    END as current_step
FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id = v.id
LEFT JOIN public.customer_profiles cp ON o.customer_id = cp.id
LEFT JOIN public.delivery_riders dr ON o.rider_id = dr.id;

CREATE OR REPLACE FUNCTION public.place_order_v7(
    p_customer_id TEXT,
    p_vendor_id TEXT,
    p_items JSONB,
    p_total DECIMAL,
    p_address TEXT,
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION,
    p_payment_method TEXT,
    p_instructions TEXT DEFAULT '',
    p_address_id TEXT DEFAULT NULL,
    p_customer_name TEXT DEFAULT 'Guest',
    p_customer_phone TEXT DEFAULT 'No Phone'
) RETURNS TEXT AS $$
DECLARE
    v_order_id TEXT;
    v_initial_status TEXT;
    v_v_lat DOUBLE PRECISION;
    v_v_lng DOUBLE PRECISION;
BEGIN
    -- Fetch Vendor Snapshot Location to ensure Admin map works even if vendor changes
    SELECT latitude, longitude INTO v_v_lat, v_v_lng FROM public.vendors WHERE id = p_vendor_id;

    v_order_id := gen_random_uuid()::TEXT;
    v_initial_status := CASE 
        WHEN p_payment_method IN ('UPI', 'CARD') THEN 'PAYMENT_PENDING' 
        ELSE 'PLACED' 
    END;

    INSERT INTO public.orders (
        id, customer_id, vendor_id, items, total, status, 
        payment_method, payment_status, delivery_address,
        delivery_lat, delivery_lng, 
        vendor_lat, vendor_lng,
        customer_name, customer_phone,
        cooking_instructions, 
        delivery_address_id, created_at
    ) VALUES (
        v_order_id, p_customer_id, p_vendor_id, p_items, p_total, v_initial_status,
        p_payment_method, 'PENDING', p_address, 
        p_lat, p_lng,
        v_v_lat, v_v_lng,
        p_customer_name, p_customer_phone,
        p_instructions, p_address_id, NOW()
    );

    RETURN v_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 11. LOGISTICS ENGINE (Status & Assignment)
CREATE OR REPLACE FUNCTION public.assign_rider_v1(p_order_id TEXT, p_rider_id TEXT)
RETURNS VOID AS $$
BEGIN
    UPDATE public.orders 
    SET status = 'RIDER_ASSIGNED',
        rider_id = p_rider_id,
        assigned_at = now()
    WHERE id = p_order_id;
    
    -- Update Rider Status
    UPDATE public.delivery_riders SET status = 'BUSY' WHERE id = p_rider_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.admin_override_status(p_order_id TEXT, p_status TEXT)
RETURNS VOID AS $$
BEGIN
    UPDATE public.orders 
    SET status = p_status,
        delivered_at = CASE WHEN p_status = 'DELIVERED' THEN now() ELSE delivered_at END,
        cancelled_at = CASE WHEN p_status = 'CANCELLED' THEN now() ELSE cancelled_at END
    WHERE id = p_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 12. TRACKING ENGINE (Live Sync + ETA)
CREATE OR REPLACE FUNCTION public.update_order_tracking_v1(
    p_order_id TEXT, p_rider_id TEXT, p_lat DOUBLE PRECISION, p_lng DOUBLE PRECISION,
    p_speed DOUBLE PRECISION, p_heading DOUBLE PRECISION
)
RETURNS VOID AS $$
DECLARE
    v_dest_lat DOUBLE PRECISION;
    v_dest_lng DOUBLE PRECISION;
    v_dist_km DOUBLE PRECISION;
    v_eta_min INTEGER;
BEGIN
    -- 1. Sync coordinates to the Order table for Real-time Admin/Customer Map
    UPDATE public.orders 
    SET rider_lat = p_lat,
        rider_lng = p_lng,
        rider_last_seen = now()
    WHERE id = p_order_id;

    -- 2. Calculate Live ETA (Distance / Urban Speed ~ 30km/h)
    SELECT delivery_lat, delivery_lng INTO v_dest_lat, v_dest_lng FROM public.orders WHERE id = p_order_id;
    
    -- Simple Haversine approximation or just Euclidean for short distances in km
    v_dist_km := 111 * sqrt(pow(v_dest_lat - p_lat, 2) + pow(v_dest_lng - p_lng, 2));
    v_eta_min := GREATEST(1, ROUND((v_dist_km / 30) * 60)); -- Distance / Speed (30km/h)

    UPDATE public.orders 
    SET estimated_arrival_time = v_eta_min::TEXT || ' mins'
    WHERE id = p_order_id;

    -- 3. Update History (Optional logs)
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'order_live_tracking') THEN
        INSERT INTO public.order_live_tracking (order_id, rider_id, rider_lat, rider_lng, speed, heading)
        VALUES (p_order_id, p_rider_id, p_lat, p_lng, p_speed, p_heading);
    END IF;
    
    -- 4. Sync to Rider Node
    UPDATE public.delivery_riders 
    SET current_lat = p_lat, current_lng = p_lng, last_gps_update = now()
    WHERE id = p_rider_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 13. ENABLE REAL-TIME BROADCASTS
ALTER TABLE public.orders REPLICA IDENTITY FULL;
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

COMMIT;
SELECT 'IDENTITY MIGRATION COMPLETE - ALL IDs ARE TEXT' as status;
