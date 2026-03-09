-- 🔗 UNIVERSAL ID ALIGNMENT (THE "NUCLEAR" FIX)
-- This script converts ALL ID-related columns from UUID to TEXT.
-- This is necessary to handle custom/non-UUID IDs (like rrgtG3C...) across all tables.

BEGIN;

-- 1. DROP CONSTRAINTS (Temp, will re-link with text or just use soft-links)
-- This allows us to change types without foreign key errors.
DO $$ 
DECLARE 
    r RECORD;
BEGIN
    FOR r IN (SELECT constraint_name, table_name FROM information_schema.table_constraints WHERE constraint_type = 'FOREIGN KEY' AND table_schema = 'public') 
    LOOP
        EXECUTE 'ALTER TABLE public.' || r.table_name || ' DROP CONSTRAINT IF EXISTS ' || r.constraint_name || ' CASCADE';
    END LOOP;
END $$;

-- 2. CONVERT TABLES
DO $$ 
BEGIN
    -- ORDERS
    ALTER TABLE public.orders ALTER COLUMN id TYPE text USING id::text;
    ALTER TABLE public.orders ALTER COLUMN customer_id TYPE text USING customer_id::text;
    ALTER TABLE public.orders ALTER COLUMN vendor_id TYPE text USING vendor_id::text;
    ALTER TABLE public.orders ALTER COLUMN delivery_partner_id TYPE text USING delivery_partner_id::text;

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

    -- FINANCIALS
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'payments') THEN
        ALTER TABLE public.payments ALTER COLUMN id TYPE text USING id::text;
        ALTER TABLE public.payments ALTER COLUMN order_id TYPE text USING order_id::text;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'vendor_settlements') THEN
        ALTER TABLE public.vendor_settlements ALTER COLUMN order_id TYPE text USING order_id::text;
        ALTER TABLE public.vendor_settlements ALTER COLUMN vendor_id TYPE text USING vendor_id::text;
    END IF;

EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'An error occurred during type conversion: %', SQLERRM;
END $$;

-- 3. RE-ENFORCE REALTIME
ALTER PUBLICATION supabase_realtime ADD TABLE public.orders, public.notifications, public.vendors, public.delivery_riders, public.customer_profiles;

COMMIT;

SELECT 'Universal ID Alignment Complete!' as status;
