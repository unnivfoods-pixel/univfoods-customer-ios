-- THE "FULL ADDRESS REPAIR" (v9.0)
-- This script fixes the "text = uuid" error and adds full address/pincode support.

BEGIN;

-- 1. KILL THE OLD VIEW
DROP VIEW IF EXISTS public.order_details_v3 CASCADE;

-- 2. SCHEMA REPAIR: Add pincode support to orders
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_pincode TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_house_number TEXT; -- For more detail
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_phone TEXT; -- Snapshot of phone used for address

-- 3. IDENTITY SYNC: Fix the "text = uuid" error
-- We cast both sides to TEXT to ensure equality works no matter the underlying type.
DO $$
BEGIN
    INSERT INTO public.users (id, email, full_name)
    SELECT id::TEXT, email, 'Logistics User'
    FROM auth.users
    WHERE id::TEXT NOT IN (SELECT id::TEXT FROM public.users)
    ON CONFLICT (id) DO NOTHING;
END $$;

-- 4. REBUILD VIEW WITH FULL ADDRESS SUPPORT
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
    o.delivery_pincode, -- New column for admin!
    o.delivery_house_number, -- New column!
    o.delivery_phone, -- Address-specific phone!
    o.vendor_lat,
    o.vendor_lng,
    o.rider_lat,
    o.rider_lng,
    o.rider_last_seen,
    o.estimated_arrival_time,
    o.created_at,
    -- IDENTITY PROTECTION
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
        'User: ' || SUBSTRING(COALESCE(o.customer_id, 'Guest'), 1, 8)
    ) as customer_name,
    COALESCE(
        NULLIF(TRIM(o.delivery_phone::TEXT), ''), -- Priority for delivery phone
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

-- 5. PERMISSIONS
GRANT SELECT ON public.order_details_v3 TO anon, authenticated, service_role;

COMMIT;

SELECT 'FULL ADDRESS IDENTITY SYSTEM (v9.0) - REPAIRED' as report;
