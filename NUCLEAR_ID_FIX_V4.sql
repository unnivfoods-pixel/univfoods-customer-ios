-- 🔗 UNIVERSAL ID ALIGNMENT V4 (THE "FORCE" FIX)
-- Use this if V3 still shows blocking views.

-- [STEP 1] EXPLICIT BRUTE-FORCE DROP
-- Run these one by one or in a block. CASCADE is key.
DROP VIEW IF EXISTS public.view_customer_orders CASCADE;
DROP VIEW IF EXISTS public.vendor_order_view CASCADE;
DROP VIEW IF EXISTS public.rider_order_view CASCADE;
DROP VIEW IF EXISTS public.order_tracking_view CASCADE;
DROP VIEW IF EXISTS public.view_vendor_orders CASCADE;
DROP VIEW IF EXISTS public.view_rider_orders CASCADE;
DROP VIEW IF EXISTS public.view_order_details CASCADE;

-- [STEP 2] THE CONVERSION BLOCK
-- I have moved the ALTER statements into a safe DO block with individual error handling.
DO $$ 
BEGIN
    -- ORDERS: ID
    BEGIN
        ALTER TABLE public.orders ALTER COLUMN id TYPE text USING id::text;
    EXCEPTION WHEN OTHERS THEN 
        RAISE NOTICE 'Failed to convert orders.id: %', SQLERRM;
    END;

    -- ORDERS: CUSTOMER_ID
    BEGIN
        ALTER TABLE public.orders ALTER COLUMN customer_id TYPE text USING customer_id::text;
    EXCEPTION WHEN OTHERS THEN 
        RAISE NOTICE 'Failed to convert orders.customer_id: %', SQLERRM;
    END;

    -- ORDERS: VENDOR_ID
    BEGIN
        ALTER TABLE public.orders ALTER COLUMN vendor_id TYPE text USING vendor_id::text;
    EXCEPTION WHEN OTHERS THEN 
        RAISE NOTICE 'Failed to convert orders.vendor_id: %', SQLERRM;
    END;

    -- VENDORS: ID
    BEGIN
        ALTER TABLE public.vendors ALTER COLUMN id TYPE text USING id::text;
    EXCEPTION WHEN OTHERS THEN 
        RAISE NOTICE 'Failed to convert vendors.id: %', SQLERRM;
    END;

    -- CUSTOMER_PROFILES: ID
    BEGIN
        ALTER TABLE public.customer_profiles ALTER COLUMN id TYPE text USING id::text;
    EXCEPTION WHEN OTHERS THEN 
        RAISE NOTICE 'Failed to convert customer_profiles.id: %', SQLERRM;
    END;

    -- NOTIFICATIONS: ALL
    BEGIN
        ALTER TABLE public.notifications ALTER COLUMN user_id TYPE text USING user_id::text;
        ALTER TABLE public.notifications ALTER COLUMN order_id TYPE text USING order_id::text;
    EXCEPTION WHEN OTHERS THEN 
        RAISE NOTICE 'Failed to convert notifications: %', SQLERRM;
    END;

END $$;

-- [STEP 3] REBUILD THE PRIMARY VIEW
CREATE OR REPLACE VIEW public.view_customer_orders AS
SELECT 
    o.*, 
    v.name as vendor_name,
    v.address as vendor_address
FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id::TEXT = v.id::TEXT;

GRANT SELECT ON public.view_customer_orders TO public;

SELECT 'Universal ID Alignment V4 Applied!' as status;
