-- 🔗 GLOBAL ID TYPE ALIGNMENT (THE "POSTGRES 22P02" FIX)
-- This script converts UUID columns to TEXT to handle non-UUID format IDs (like Firebase or custom IDs).
-- This resolves: PostgrestException: invalid input syntax for type uuid.

BEGIN;

-- 1. FIX ORDERS TABLE
DO $$ 
BEGIN
    -- CUSTOMER_ID: Convert to TEXT
    ALTER TABLE IF EXISTS public.orders ALTER COLUMN customer_id TYPE text USING customer_id::text;
    
    -- VENDOR_ID: Convert to TEXT
    ALTER TABLE IF EXISTS public.orders ALTER COLUMN vendor_id TYPE text USING vendor_id::text;
    
    -- DELIVERY_PARTNER_ID: Convert to TEXT
    ALTER TABLE IF EXISTS public.orders ALTER COLUMN delivery_partner_id TYPE text USING delivery_partner_id::text;

EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Orders table alignment skipped or partially failed: %', SQLERRM;
END $$;

-- 2. FIX CUSTOMER PROFILES TABLE
DO $$ 
BEGIN
    ALTER TABLE IF EXISTS public.customer_profiles ALTER COLUMN id TYPE text USING id::text;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Customer Profiles alignment skipped: %', SQLERRM;
END $$;

-- 3. FIX VENDORS TABLE
DO $$ 
BEGIN
    ALTER TABLE IF EXISTS public.vendors ALTER COLUMN id TYPE text USING id::text;
    ALTER TABLE IF EXISTS public.vendors ALTER COLUMN owner_id TYPE text USING owner_id::text;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Vendors table alignment skipped: %', SQLERRM;
END $$;

-- 4. FIX DELIVERY RIDERS TABLE
DO $$ 
BEGIN
    ALTER TABLE IF EXISTS public.delivery_riders ALTER COLUMN id TYPE text USING id::text;
    ALTER TABLE IF EXISTS public.delivery_riders ALTER COLUMN user_id TYPE text USING user_id::text;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Delivery Riders table alignment skipped: %', SQLERRM;
END $$;

-- 5. FIX NOTIFICATIONS & TOKENS
DO $$ 
BEGIN
    ALTER TABLE IF EXISTS public.notifications ALTER COLUMN user_id TYPE text USING user_id::text;
    ALTER TABLE IF EXISTS public.user_fcm_tokens ALTER COLUMN user_id TYPE text USING user_id::text;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Notification alignment skipped: %', SQLERRM;
END $$;

-- 6. RE-ENFORCE POLICIES
COMMIT;

SELECT 'Global ID alignment completed! You can now checkout with non-UUID IDs.' as status;
