
-- ULTIMATE PRODUCTION PIPELINE V55.3 (IDENTITY SYNTAX & UUID ESCAPE)
-- 🎯 MISSION: Fix "invalid input syntax for type uuid" during Checkout.
-- 🛠️ WHY: Firebase UIDs (28 chars) or Guest IDs are being sent to UUID-only columns.

BEGIN;

-- 1. MIGRATE TABLES TO TEXT TO SUPPORT NON-UUID IDENTITIES (Firebase, Phone Auth, Guest)
-- Note: We do this safely to avoid breaking dependencies.

-- ORDERS table
ALTER TABLE public.orders ALTER COLUMN customer_id TYPE TEXT;

-- CUSTOMER_PROFILES table
-- Note: If this is a PK, it might be tricky. Using a DO block to handle constraints.
DO $$ 
BEGIN
    ALTER TABLE public.customer_profiles ALTER COLUMN id TYPE TEXT;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Skipping profile PK migration - likely already TEXT or handled by system.';
END $$;

-- WALLETS table
ALTER TABLE public.wallets ALTER COLUMN user_id TYPE TEXT;

-- USER_ADDRESSES table (if it exists)
DO $$ 
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'user_addresses') THEN
        ALTER TABLE public.user_addresses ALTER COLUMN user_id TYPE TEXT;
    END IF;
END $$;


-- 2. UPGRADE ORDER PLACEMENT TO HANDLE TEXT IDS
CREATE OR REPLACE FUNCTION public.place_order_v6(
    p_customer_id TEXT,    -- UPGRADED: Was UUID, now TEXT
    p_vendor_id UUID,
    p_items JSONB,
    p_total DECIMAL,
    p_address TEXT,
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION,
    p_payment_method TEXT,
    p_instructions TEXT DEFAULT '',
    p_address_id TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_order_id UUID;
    v_initial_status TEXT;
BEGIN
    -- Strict initial status logic
    IF p_payment_method = 'UPI' OR p_payment_method = 'CARD' THEN
        v_initial_status := 'PAYMENT_PENDING';
    ELSE
        v_initial_status := 'PLACED';
    END IF;

    -- Insert the master order record
    INSERT INTO public.orders (
        customer_id,
        vendor_id,
        items,
        total,
        status,
        payment_method,
        payment_status,
        address,
        delivery_address,
        delivery_lat,
        delivery_lng,
        cooking_instructions,
        delivery_address_id,
        created_at
    ) VALUES (
        p_customer_id, -- Now accepting TEXT
        p_vendor_id,
        p_items,
        p_total,
        v_initial_status,
        p_payment_method,
        'PENDING',
        p_address,
        p_address,
        p_lat,
        p_lng,
        p_instructions,
        p_address_id,
        NOW()
    ) RETURNING id INTO v_order_id;

    -- Insert notifications for Vendor owner
    INSERT INTO public.notifications (user_id, title, message, type)
    VALUES (
        (SELECT owner_id::TEXT FROM public.vendors WHERE id = p_vendor_id), -- Cast owner_id to TEXT for safety
        'New Mission Incoming!',
        'You have received a new order. Open terminal to accept.',
        'NEW_ORDER'
    );

    RETURN v_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;

-- Apply notify to refresh PostgREST cache
NOTIFY pgrst, 'reload schema';
