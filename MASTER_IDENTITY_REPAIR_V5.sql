-- THE "HELL-FIRE" IDENTITY & LOGISTICS REPAIR (v5.0 - ABSOLUTE ALIGNMENT)
-- This script fixes the blank Names/Orders for REAL logged-in users and vendors
-- Handles the UUID type mismatch and view join errors properly.

BEGIN;

-- 1. KILL ALL STUCK VIEWS
DROP VIEW IF EXISTS public.order_details_v3 CASCADE;
DROP VIEW IF EXISTS public.order_tracking_v1 CASCADE;

-- 2. SELF-HEALING IDENTITY TABLES
-- We force 'id' to TEXT in our repair logic to handle all formats without crashing.
DO $$ 
BEGIN
    -- Fix users table
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users') THEN
        CREATE TABLE public.users (
            id TEXT PRIMARY KEY,
            full_name TEXT,
            name TEXT,
            phone TEXT,
            email TEXT,
            avatar_url TEXT,
            created_at TIMESTAMPTZ DEFAULT now()
        );
    ELSE
        -- Ensure columns exist
        ALTER TABLE public.users ADD COLUMN IF NOT EXISTS email TEXT;
        ALTER TABLE public.users ADD COLUMN IF NOT EXISTS full_name TEXT;
        ALTER TABLE public.users ADD COLUMN IF NOT EXISTS name TEXT;
        ALTER TABLE public.users ADD COLUMN IF NOT EXISTS phone TEXT;
        ALTER TABLE public.users ADD COLUMN IF NOT EXISTS avatar_url TEXT;
        
        -- If ID is UUID, we might need a separate sync strategy, but for now we try to cast.
    END IF;

    -- Fix customer_profiles table
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'customer_profiles') THEN
        CREATE TABLE public.customer_profiles (
            id TEXT PRIMARY KEY,
            full_name TEXT,
            phone TEXT,
            avatar_url TEXT,
            created_at TIMESTAMPTZ DEFAULT now()
        );
    ELSE
        ALTER TABLE public.customer_profiles ADD COLUMN IF NOT EXISTS full_name TEXT;
        ALTER TABLE public.customer_profiles ADD COLUMN IF NOT EXISTS phone TEXT;
    END IF;
END $$;

-- 3. IDENTITY SYNC: Link Auth users to public users
-- We use a CROSS-TYPE INSERT that handles UUID to TEXT conversion automatically.
DO $$
BEGIN
    INSERT INTO public.users (id, email)
    SELECT id::TEXT, email FROM auth.users
    ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email;
EXCEPTION WHEN OTHERS THEN
    -- If id is truly a UUID column in public.users, we insert directly
    INSERT INTO public.users (id, email)
    SELECT id, email FROM auth.users
    ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email;
END $$;

-- 4. REBUILD THE TRUTH VIEW (With Cast-Safe Joins)
-- We cast every ID to TEXT before joining to prevent "btrim(uuid)" errors.
CREATE VIEW public.order_details_v3 AS
SELECT 
    o.id::TEXT as order_id,
    o.customer_id::TEXT,
    o.vendor_id::TEXT,
    o.rider_id::TEXT,
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
    -- VENDOR/STATION NAME (Curry Point Name)
    COALESCE(
        NULLIF(TRIM(v.name::TEXT), ''), 
        NULLIF(TRIM(o.vendor_name::TEXT), ''), 
        'Station: ' || COALESCE(NULLIF(TRIM(o.vendor_id::TEXT), ''), 'Unknown')
    ) as vendor_name,
    v.phone::TEXT as vendor_phone,
    v.address::TEXT as vendor_address,
    -- CUSTOMER IDENTITY (Logged-in User Name)
    COALESCE(
        NULLIF(TRIM(u.full_name::TEXT), ''), 
        NULLIF(TRIM(u.name::TEXT), ''), 
        NULLIF(TRIM(cp.full_name::TEXT), ''), 
        NULLIF(TRIM(o.customer_name::TEXT), ''), 
        'User: ' || COALESCE(NULLIF(TRIM(o.customer_id::TEXT), ''), 'Guest')
    ) as customer_name,
    COALESCE(
        NULLIF(TRIM(u.phone::TEXT), ''), 
        NULLIF(TRIM(cp.phone::TEXT), ''), 
        NULLIF(TRIM(o.customer_phone::TEXT), ''), 
        'No Phone'
    ) as customer_phone,
    COALESCE(u.avatar_url, cp.avatar_url) as customer_avatar,
    -- RIDER IDENTITY
    COALESCE(
        NULLIF(TRIM(dr.name::TEXT), ''), 
        'Unit: ' || COALESCE(NULLIF(TRIM(o.rider_id::TEXT), ''), 'Unassigned')
    ) as rider_name,
    dr.phone::TEXT as rider_phone,
    dr.vehicle_number::TEXT as rider_vehicle
FROM public.orders o
LEFT JOIN public.vendors v ON TRIM(o.vendor_id::TEXT) = TRIM(v.id::TEXT)
LEFT JOIN public.users u ON TRIM(o.customer_id::TEXT) = TRIM(u.id::TEXT)
LEFT JOIN public.customer_profiles cp ON TRIM(o.customer_id::TEXT) = TRIM(cp.id::TEXT)
LEFT JOIN public.delivery_riders dr ON TRIM(o.rider_id::TEXT) = TRIM(dr.id::TEXT);

-- 5. PERMISSIONS REINFORCEMENT
ALTER VIEW public.order_details_v3 OWNER TO postgres;
GRANT SELECT ON public.order_details_v3 TO authenticated, anon, service_role;

-- 6. REALTIME LOGISTICS BROADCAST
ALTER TABLE public.orders REPLICA IDENTITY FULL;
ALTER TABLE public.vendors REPLICA IDENTITY FULL;
ALTER TABLE public.delivery_riders REPLICA IDENTITY FULL;

COMMIT;

SELECT 'IDENTITY GRID REPAIRED (v5.0) - REALTIME SYNC ACTIVE' as report;
