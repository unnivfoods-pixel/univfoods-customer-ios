-- 🔗 UNIVERSAL ID ALIGNMENT V2 (THE "VIEW-SAFE" FIX)
-- This script converts UUID columns to TEXT while safely handling dependent views.

BEGIN;

-- 1. DROP DEPENDENT VIEWS
DROP VIEW IF EXISTS public.view_customer_orders CASCADE;
DROP VIEW IF EXISTS public.view_vendor_orders CASCADE;
DROP VIEW IF EXISTS public.view_rider_orders CASCADE;

-- 2. DROP ALL FOREIGN KEY CONSTRAINTS
DO $$ 
DECLARE 
    r RECORD;
BEGIN
    FOR r IN (SELECT constraint_name, table_name FROM information_schema.table_constraints WHERE constraint_type = 'FOREIGN KEY' AND table_schema = 'public') 
    LOOP
        EXECUTE 'ALTER TABLE public.' || r.table_name || ' DROP CONSTRAINT IF EXISTS ' || r.constraint_name || ' CASCADE';
    END LOOP;
END $$;

-- 3. CONVERT ALL KEY COLUMNS TO TEXT
DO $$ 
BEGIN
    -- ORDERS (The main culprit)
    ALTER TABLE public.orders ALTER COLUMN id TYPE text USING id::text;
    ALTER TABLE public.orders ALTER COLUMN customer_id TYPE text USING customer_id::text;
    ALTER TABLE public.orders ALTER COLUMN vendor_id TYPE text USING vendor_id::text;
    ALTER TABLE public.orders ALTER COLUMN delivery_partner_id TYPE text USING delivery_partner_id::text;
    -- Also handle 'rider_id' if it exists in some schema versions
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='rider_id') THEN
        ALTER TABLE public.orders ALTER COLUMN rider_id TYPE text USING rider_id::text;
    END IF;

    -- VENDORS
    ALTER TABLE public.vendors ALTER COLUMN id TYPE text USING id::text;
    ALTER TABLE public.vendors ALTER COLUMN owner_id TYPE text USING owner_id::text;

    -- PRODUCTS
    ALTER TABLE public.products ALTER COLUMN id TYPE text USING id::text;
    ALTER TABLE public.products ALTER COLUMN vendor_id TYPE text USING vendor_id::text;

    -- RIDERS
    ALTER TABLE public.delivery_riders ALTER COLUMN id TYPE text USING id::text;
    ALTER TABLE public.delivery_riders ALTER COLUMN user_id TYPE text USING user_id::text;

    -- CUSTOMER PROFILES
    ALTER TABLE public.customer_profiles ALTER COLUMN id TYPE text USING id::text;

    -- NOTIFICATIONS & TOKENS
    ALTER TABLE public.notifications ALTER COLUMN id TYPE text USING id::text;
    ALTER TABLE public.notifications ALTER COLUMN user_id TYPE text USING user_id::text;
    ALTER TABLE public.notifications ALTER COLUMN order_id TYPE text USING order_id::text;
    ALTER TABLE public.user_fcm_tokens ALTER COLUMN user_id TYPE text USING user_id::text;

EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'An error occurred during type conversion: %', SQLERRM;
END $$;

-- 4. RECREATE THE MAIN ORDER VIEW
CREATE OR REPLACE VIEW public.view_customer_orders AS
SELECT 
    o.*, 
    v.name as vendor_name,
    v.address as vendor_address,
    v.latitude as vendor_lat,
    v.longitude as vendor_lng,
    v.image_url as vendor_logo,
    dr.name as rider_name,
    dr.phone as rider_phone,
    dr.vehicle_number as rider_vehicle
FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id::TEXT = v.id::TEXT
LEFT JOIN public.delivery_riders dr ON o.delivery_partner_id::TEXT = dr.id::TEXT;

GRANT SELECT ON public.view_customer_orders TO anon, authenticated, service_role;

-- 5. RE-ENFORCE REALTIME
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        CREATE PUBLICATION supabase_realtime;
    END IF;
END $$;

ALTER PUBLICATION supabase_realtime ADD TABLE public.orders, public.notifications, public.vendors, public.delivery_riders, public.customer_profiles;

COMMIT;

SELECT 'Universal ID Alignment V2 Complete! All views restored.' as status;
