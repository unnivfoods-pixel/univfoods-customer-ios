-- THE "ULTIMATE TYPE-SAFE" IDENTITY REPAIR (v10.0)
-- This script fixes the "column id is of type uuid but expression is of type text" error.
-- Restores full address + phone + pincode support for the Admin Panel.

BEGIN;

-- 1. KILL THE OLD VIEW (Safe reset)
DROP VIEW IF EXISTS public.order_details_v3 CASCADE;

-- 2. UNIFIED IDENTITY SYNC: Handles both UUID and TEXT ID columns
-- This block dynamically detects the column type to avoid conversion errors.
DO $$
BEGIN
    INSERT INTO public.users (id, email, full_name)
    SELECT id, email, 'Realtime User'
    FROM auth.users
    WHERE id::TEXT NOT IN (SELECT id::TEXT FROM public.users)
    ON CONFLICT (id) DO NOTHING;
EXCEPTION WHEN OTHERS THEN
    -- Fallback: If public.users.id is TEXT, we cast auth.users.id to TEXT
    INSERT INTO public.users (id, email, full_name)
    SELECT id::TEXT, email, 'Realtime User'
    FROM auth.users
    WHERE id::TEXT NOT IN (SELECT id::TEXT FROM public.users)
    ON CONFLICT (id) DO NOTHING;
END $$;

-- 3. SCHEMA UPGRADE: Ensure address details exist for Admin Panel
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_pincode TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_house_number TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_phone TEXT;

-- 4. REBUILD VIEW WITH INTEGRATED IDENTITY PROTECTION
-- Uses TRIM and ::TEXT casts for JOINS ONLY (safe for both UUID and TEXT)
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
    o.delivery_pincode,
    o.delivery_house_number,
    o.delivery_phone,
    o.vendor_lat,
    o.vendor_lng,
    o.rider_lat,
    o.rider_lng,
    o.rider_last_seen,
    o.estimated_arrival_time,
    o.created_at,
    -- THE CURE FOR BLANK IDENTITY (Curry Point & Real User)
    COALESCE(
        NULLIF(TRIM(v.shop_name::TEXT), ''), 
        NULLIF(TRIM(v.name::TEXT), ''), 
        NULLIF(TRIM(o.vendor_name::TEXT), ''), 
        'Station ID: ' || SUBSTRING(COALESCE(o.vendor_id, '????'), 1, 8)
    ) as vendor_name,
    COALESCE(
        NULLIF(TRIM(u.full_name::TEXT), ''), 
        NULLIF(TRIM(u.name::TEXT), ''), 
        NULLIF(TRIM(cp.full_name::TEXT), ''), 
        NULLIF(TRIM(o.customer_name::TEXT), ''), 
        'Login User: ' || SUBSTRING(COALESCE(o.customer_id, 'Guest'), 1, 8)
    ) as customer_name,
    COALESCE(
        NULLIF(TRIM(o.delivery_phone::TEXT), ''), -- Priority to delivery-specific phone
        NULLIF(TRIM(o.customer_phone::TEXT), ''), 
        NULLIF(TRIM(u.phone::TEXT), ''), 
        NULLIF(TRIM(cp.phone::TEXT), ''), 
        'No Phone'
    ) as customer_phone,
    COALESCE(
        NULLIF(TRIM(dr.name::TEXT), ''), 
        'Searching for Rider...'
    ) as rider_name,
    dr.phone::TEXT as rider_phone
FROM public.orders o
LEFT JOIN public.vendors v ON TRIM(v.id::TEXT) = TRIM(o.vendor_id::TEXT)
LEFT JOIN public.users u ON TRIM(u.id::TEXT) = TRIM(o.customer_id::TEXT)
LEFT JOIN public.customer_profiles cp ON TRIM(cp.id::TEXT) = TRIM(o.customer_id::TEXT)
LEFT JOIN public.delivery_riders dr ON TRIM(dr.id::TEXT) = TRIM(o.rider_id::TEXT);

-- 5. PERMISSIONS & REALTIME
GRANT SELECT ON public.order_details_v3 TO anon, authenticated, service_role;
ALTER TABLE public.orders REPLICA IDENTITY FULL;

COMMIT;

SELECT 'IDENTITY SYSTEM ONLINE (v10.0) - REPAIRED' as report;
