-- THE "TRIPLE THREAT" IDENTITY & SCHEMA REPAIR (v7.0)
-- This script fixes the "Status" column errors and restores the "Curry Point" names.

BEGIN;

-- 1. KILL THE OLD VIEW
DROP VIEW IF EXISTS public.order_details_v3 CASCADE;

-- 2. SCHEMA ALIGNMENT: Add missing 'status' columns (Frontend depends on these!)
ALTER TABLE public.delivery_riders ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'Offline';
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'OFFLINE';
ALTER TABLE public.delivery_riders ADD COLUMN IF NOT EXISTS is_online BOOLEAN DEFAULT false;

-- 3. RECOVER MISSING VENDORS
-- If an order has a vendor_id that doesn't exist, we create a placeholder so the name isn't blank.
INSERT INTO public.vendors (id, name, status)
SELECT DISTINCT vendor_id, 'Restored Station (' || SUBSTRING(vendor_id, 1, 8) || ')', 'ONLINE'
FROM public.orders
WHERE vendor_id IS NOT NULL 
AND vendor_id NOT IN (SELECT id FROM public.vendors)
ON CONFLICT (id) DO NOTHING;

-- 4. IDENTITY SYNC: Ensure Realtime Users exist in public.users
INSERT INTO public.users (id, email, full_name)
SELECT id::TEXT, email, 'Realtime User'
FROM auth.users
WHERE id::TEXT NOT IN (SELECT id FROM public.users)
ON CONFLICT (id) DO NOTHING;

-- 5. REBUILD VIEW WITH POWERFUL JOINS
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
    o.created_at,
    -- THE CURE FOR BLANK NAMES:
    COALESCE(
        NULLIF(TRIM(v.name::TEXT), ''), 
        NULLIF(TRIM(o.vendor_name::TEXT), ''), 
        'Station: ' || COALESCE(NULLIF(TRIM(o.vendor_id::TEXT), ''), 'Unknown')
    ) as vendor_name,
    COALESCE(
        NULLIF(TRIM(u.full_name::TEXT), ''), 
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
    COALESCE(
        NULLIF(TRIM(dr.name::TEXT), ''), 
        'Unit: ' || COALESCE(NULLIF(TRIM(o.rider_id::TEXT), ''), 'Unassigned')
    ) as rider_name,
    dr.phone::TEXT as rider_phone,
    dr.status as rider_status_db -- Using reconstructed status
FROM public.orders o
LEFT JOIN public.vendors v ON TRIM(v.id::TEXT) = TRIM(o.vendor_id::TEXT)
LEFT JOIN public.users u ON TRIM(u.id::TEXT) = TRIM(o.customer_id::TEXT)
LEFT JOIN public.customer_profiles cp ON TRIM(cp.id::TEXT) = TRIM(o.customer_id::TEXT)
LEFT JOIN public.delivery_riders dr ON TRIM(dr.id::TEXT) = TRIM(o.rider_id::TEXT);

-- 6. PERMISSIONS & REALTIME
GRANT SELECT ON public.order_details_v3 TO anon, authenticated, service_role;
ALTER TABLE public.orders REPLICA IDENTITY FULL;

COMMIT;

SELECT 'IDENTITY GRID REPAIRED (v7.0) - STATUS COLUMNS ADDED' as report;
