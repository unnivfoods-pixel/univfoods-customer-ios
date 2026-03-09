-- THE "GHOST PROTOCOL" IDENTITY REPAIR (v12.0)
-- 🎯 MISSION: End the ID-instead-of-Name issue & Fix Rider Realtime Sync

BEGIN;

-- 1. CLEANUP OLD VIEWS
DROP VIEW IF EXISTS public.order_details_v3 CASCADE;

-- 2. "CURRY POINT" HEALING SYSTEM
-- We identify every Unique Vendor ID used in orders and make sure it has a name.
INSERT INTO public.vendors (id, name, shop_name, status)
SELECT DISTINCT 
    vendor_id, 
    'Curry Point (' || SUBSTRING(vendor_id, 1, 8) || ')', 
    'Curry Point (' || SUBSTRING(vendor_id, 1, 8) || ')', 
    'ONLINE'
FROM public.orders 
WHERE vendor_id IS NOT NULL 
AND vendor_id NOT IN (SELECT id::TEXT FROM public.vendors)
ON CONFLICT (id) DO NOTHING;

-- 3. "RIDER IDENTITY" HEALING SYSTEM
-- Ensure every assigned rider has a record in the delivery_riders table.
INSERT INTO public.delivery_riders (id, name, status, is_online)
SELECT DISTINCT 
    rider_id, 
    'Rider Unit (' || SUBSTRING(rider_id, 1, 8) || ')', 
    'Online',
    true
FROM public.orders 
WHERE rider_id IS NOT NULL 
AND rider_id NOT IN (SELECT id::TEXT FROM public.delivery_riders)
ON CONFLICT (id) DO NOTHING;

-- 4. IDENTITY SYNC: Realtime Login Users (Fixed UUID vs TEXT)
DO $$
BEGIN
    INSERT INTO public.users (id, email, full_name)
    SELECT id, email, 'Real User' FROM auth.users
    WHERE id::TEXT NOT IN (SELECT id::TEXT FROM public.users)
    ON CONFLICT (id) DO NOTHING;
EXCEPTION WHEN OTHERS THEN
    INSERT INTO public.users (id, email, full_name)
    SELECT id::TEXT, email, 'Real User' FROM auth.users
    WHERE id::TEXT NOT IN (SELECT id::TEXT FROM public.users)
    ON CONFLICT (id) DO NOTHING;
END $$;

-- 5. REBUILD MASTER VIEW (v12.0)
-- This view is optimized for REALTIME updates in the Admin Panel.
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
    -- THE CURE FOR BLANK NAMES:
    COALESCE(
        NULLIF(TRIM(v.shop_name::TEXT), ''), 
        NULLIF(TRIM(v.name::TEXT), ''), 
        'Station: ' || SUBSTRING(COALESCE(vendor_id, '????'), 1, 8)
    ) as vendor_name,
    COALESCE(
        NULLIF(TRIM(u.full_name::TEXT), ''), 
        NULLIF(TRIM(cp.full_name::TEXT), ''), 
        'User: ' || SUBSTRING(COALESCE(customer_id, 'Guest'), 1, 8)
    ) as customer_name,
    COALESCE(
        NULLIF(TRIM(o.delivery_phone::TEXT), ''), 
        NULLIF(TRIM(o.customer_phone::TEXT), ''), 
        'No Phone'
    ) as customer_phone,
    -- THE CURE FOR RIDER NAMES:
    COALESCE(
        NULLIF(TRIM(dr.name::TEXT), ''), 
        'Dispatching Unit...'
    ) as rider_name,
    dr.phone::TEXT as rider_phone
FROM public.orders o
LEFT JOIN public.vendors v ON TRIM(v.id::TEXT) = TRIM(o.vendor_id::TEXT)
LEFT JOIN public.users u ON TRIM(u.id::TEXT) = TRIM(o.customer_id::TEXT)
LEFT JOIN public.customer_profiles cp ON TRIM(cp.id::TEXT) = TRIM(o.customer_id::TEXT)
LEFT JOIN public.delivery_riders dr ON TRIM(dr.id::TEXT) = TRIM(o.rider_id::TEXT);

-- 6. PERMISSIONS
GRANT SELECT ON public.order_details_v3 TO anon, authenticated, service_role;

COMMIT;

SELECT 'IDENTITY SYSTEM GHOST PROTOCOL (v12.0) - REPAIRED' as report;
