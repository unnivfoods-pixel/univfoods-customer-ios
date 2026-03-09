-- THE "HELL-FIRE" IDENTITY & LOGISTICS REPAIR (v3.1 - SELF-HEALING)
-- This script fixes the blank Names/Orders for REAL logged-in users and vendors

BEGIN;

-- 1. KILL ALL STUCK VIEWS
DROP VIEW IF EXISTS public.order_details_v3 CASCADE;
DROP VIEW IF EXISTS public.order_tracking_v1 CASCADE;

-- 2. SELF-HEALING USERS TABLE
DO $$ 
BEGIN
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
        -- Add missing columns to existing users table
        ALTER TABLE public.users ADD COLUMN IF NOT EXISTS email TEXT;
        ALTER TABLE public.users ADD COLUMN IF NOT EXISTS full_name TEXT;
        ALTER TABLE public.users ADD COLUMN IF NOT EXISTS name TEXT;
        ALTER TABLE public.users ADD COLUMN IF NOT EXISTS phone TEXT;
        ALTER TABLE public.users ADD COLUMN IF NOT EXISTS avatar_url TEXT;
        ALTER TABLE public.users ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();
    END IF;
END $$;

-- 3. SELF-HEALING CUSTOMER PROFILES TABLE
DO $$ 
BEGIN
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
        ALTER TABLE public.customer_profiles ADD COLUMN IF NOT EXISTS avatar_url TEXT;
        ALTER TABLE public.customer_profiles ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();
    END IF;
END $$;

-- 4. IDENTITY SYNC: Link Auth users to public users if they exist
-- This ensures "Login Realtime Users" are appearing in the grid.
INSERT INTO public.users (id, email)
SELECT id, email FROM auth.users
ON CONFLICT (id) DO NOTHING;

-- 5. REBUILD THE TRUTH VIEW (With Quad-Layer Identity Protection)
-- We join with 'users', 'customer_profiles', and snapshots to ensure NOTHING is blank.
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
    -- VENDOR NAME REPAIR (Curry Point Name Fix)
    COALESCE(
        NULLIF(TRIM(v.name), ''), 
        NULLIF(TRIM(o.vendor_name), ''), 
        'Station: ' || COALESCE(NULLIF(TRIM(o.vendor_id), ''), 'Unknown')
    ) as vendor_name,
    v.phone as vendor_phone,
    v.address as vendor_address,
    -- CUSTOMER IDENTITY REPAIR (Login User Fix)
    COALESCE(
        NULLIF(TRIM(cp.full_name), ''), 
        NULLIF(TRIM(u.full_name), ''), 
        NULLIF(TRIM(u.name), ''), 
        NULLIF(TRIM(o.customer_name), ''), 
        'User: ' || COALESCE(NULLIF(TRIM(o.customer_id), ''), 'Guest')
    ) as customer_name,
    COALESCE(
        NULLIF(TRIM(cp.phone), ''), 
        NULLIF(TRIM(u.phone), ''), 
        NULLIF(TRIM(o.customer_phone), ''), 
        'No Phone'
    ) as customer_phone,
    COALESCE(cp.avatar_url, u.avatar_url, o.customer_id) as customer_avatar,
    -- RIDER IDENTITY REPAIR
    COALESCE(
        NULLIF(TRIM(dr.name), ''), 
        'Unit: ' || COALESCE(NULLIF(TRIM(o.rider_id), ''), 'Pending')
    ) as rider_name,
    dr.phone as rider_phone,
    dr.vehicle_number as rider_vehicle,
    dr.rating as rider_rating
FROM public.orders o
LEFT JOIN public.vendors v ON TRIM(o.vendor_id) = TRIM(v.id)
LEFT JOIN public.users u ON TRIM(o.customer_id) = TRIM(u.id)
LEFT JOIN public.customer_profiles cp ON TRIM(o.customer_id) = TRIM(cp.id)
LEFT JOIN public.delivery_riders dr ON TRIM(o.rider_id) = TRIM(dr.id);

-- 6. PERMISSIONS REINFORCEMENT
-- Ensure the Admin role can bypass RLS for these lookups in the view
ALTER VIEW public.order_details_v3 OWNER TO postgres;
GRANT SELECT ON public.order_details_v3 TO authenticated, anon, service_role;

-- 7. ENABLE REALTIME FOR EVERYTHING
ALTER TABLE public.orders REPLICA IDENTITY FULL;
ALTER TABLE public.vendors REPLICA IDENTITY FULL;
ALTER TABLE public.delivery_riders REPLICA IDENTITY FULL;

COMMIT;

SELECT 'IDENTITY GRID REPAIRED (v3.1) - LOGIN USERS SYNCED' as report;
