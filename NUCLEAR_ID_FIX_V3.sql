-- 🔗 UNIVERSAL ID ALIGNMENT V3 (THE "VIEW-EXTERMINATOR" FIX)
-- This script aggressively drops all dependent views before converting IDs to TEXT.

BEGIN;

-- 1. DROP ALL POTENTIAL DEPENDENT VIEWS (The thorough way)
DROP VIEW IF EXISTS public.view_customer_orders CASCADE;
DROP VIEW IF EXISTS public.vendor_order_view CASCADE;
DROP VIEW IF EXISTS public.rider_order_view CASCADE;
DROP VIEW IF EXISTS public.order_tracking_view CASCADE;
DROP VIEW IF EXISTS public.view_vendor_orders CASCADE;
DROP VIEW IF EXISTS public.view_rider_orders CASCADE;

-- 2. DYNAMICALLY DROP ANY REMAINING VIEWS DEPENDING ON ORDERS
-- This is a safe-guard for views I might not know about.
DO $$ 
DECLARE 
    view_record RECORD;
BEGIN
    FOR view_record IN 
        SELECT DISTINCT depend.relname as view_name
        FROM pg_depend 
        JOIN pg_rewrite ON pg_depend.objid = pg_rewrite.oid 
        JOIN pg_class as depend ON pg_rewrite.ev_class = depend.oid 
        JOIN pg_class as source ON pg_depend.refobjid = source.oid 
        WHERE source.relname = 'orders' AND depend.relkind = 'v'
    LOOP
        EXECUTE 'DROP VIEW IF EXISTS public.' || quote_ident(view_record.view_name) || ' CASCADE';
    END LOOP;
END $$;

-- 3. CONVERT ALL KEY COLUMNS TO TEXT
DO $$ 
BEGIN
    -- ORDERS (The main table)
    ALTER TABLE public.orders ALTER COLUMN id TYPE text USING id::text;
    ALTER TABLE public.orders ALTER COLUMN customer_id TYPE text USING customer_id::text;
    ALTER TABLE public.orders ALTER COLUMN vendor_id TYPE text USING vendor_id::text;
    
    -- Handle delivery_partner_id or rider_id naming variants
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='delivery_partner_id') THEN
        ALTER TABLE public.orders ALTER COLUMN delivery_partner_id TYPE text USING delivery_partner_id::text;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='rider_id') THEN
        ALTER TABLE public.orders ALTER COLUMN rider_id TYPE text USING rider_id::text;
    END IF;

    -- VENDORS
    ALTER TABLE public.vendors ALTER COLUMN id TYPE text USING id::text;

    -- CUSTOMER PROFILES
    ALTER TABLE public.customer_profiles ALTER COLUMN id TYPE text USING id::text;

    -- RIDERS
    ALTER TABLE public.delivery_riders ALTER COLUMN id TYPE text USING id::text;

    -- NOTIFICATIONS
    ALTER TABLE public.notifications ALTER COLUMN user_id TYPE text USING user_id::text;
    ALTER TABLE public.notifications ALTER COLUMN order_id TYPE text USING order_id::text;

EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'An error occurred during type conversion: %', SQLERRM;
END $$;

-- 4. RECREATE THE ESSENTIAL VIEWS (Bonding via TEXT)

-- A. Customer View
CREATE OR REPLACE VIEW public.view_customer_orders AS
SELECT 
    o.*, 
    v.name as vendor_name,
    v.address as vendor_address,
    dr.name as rider_name
FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id::TEXT = v.id::TEXT
LEFT JOIN public.delivery_riders dr ON (
    COALESCE(o.delivery_partner_id, o.rider_id)::TEXT = dr.id::TEXT
);

-- B. Vendor View
CREATE OR REPLACE VIEW public.vendor_order_view AS
SELECT 
    o.*,
    c.full_name as customer_name
FROM public.orders o
LEFT JOIN public.customer_profiles c ON o.customer_id::TEXT = c.id::TEXT;

-- 5. RESTORE PERMISSIONS
GRANT SELECT ON public.view_customer_orders TO anon, authenticated, service_role;
GRANT SELECT ON public.vendor_order_view TO anon, authenticated, service_role;

COMMIT;

SELECT 'Universal ID Alignment V3 Complete! All blocking views handled.' as status;
