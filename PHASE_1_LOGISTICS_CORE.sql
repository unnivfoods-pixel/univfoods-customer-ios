-- 🛰️ PHASE 1: LOGISTICS CORE & REAL-TIME ALIGNMENT (TYPE-SAFE VERSION)
-- This script matches your existing 'orders' and 'vendors' types perfectly to avoid "Incompatible Types" errors.

BEGIN;

-- 1. DETECT CORE TYPES
DO $$
DECLARE
    order_id_type TEXT;
    vendor_id_type TEXT;
BEGIN
    -- Get existing types
    SELECT data_type INTO order_id_type FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'id';
    SELECT data_type INTO vendor_id_type FROM information_schema.columns WHERE table_name = 'vendors' AND column_name = 'id';

    -- DEFAULT to UUID if table doesn't exist yet (unlikely here)
    IF order_id_type IS NULL THEN order_id_type := 'UUID'; END IF;
    IF vendor_id_type IS NULL THEN vendor_id_type := 'UUID'; END IF;

    -- 2. EXTEND ORDERS TABLE
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS payment_type TEXT DEFAULT 'COD';
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS payment_status TEXT DEFAULT 'PENDING';
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS is_force_cancelled BOOLEAN DEFAULT FALSE;
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

    -- 3. CREATE LOGISTICS TABLES WITH MATCHING TYPES
    -- ORDER ITEMS
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'order_items') THEN
        EXECUTE format('CREATE TABLE public.order_items (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            order_id %s REFERENCES public.orders(id) ON DELETE CASCADE,
            product_id UUID REFERENCES public.products(id),
            quantity INTEGER NOT NULL DEFAULT 1,
            price_at_time NUMERIC(10,2),
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        )', order_id_type);
    END IF;

    -- TRANSACTIONS
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'transactions') THEN
        EXECUTE format('CREATE TABLE public.transactions (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            order_id %s REFERENCES public.orders(id),
            customer_id TEXT,
            amount NUMERIC(10,2),
            status TEXT,
            provider_tx_id TEXT,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        )', order_id_type);
    END IF;

    -- REFUNDS
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'refunds') THEN
        EXECUTE format('CREATE TABLE public.refunds (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            order_id %s REFERENCES public.orders(id),
            amount NUMERIC(10,2),
            status TEXT DEFAULT ''PENDING'',
            reason TEXT,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        )', order_id_type);
    END IF;

    -- SUPPORT TICKETS
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'support_tickets') THEN
        EXECUTE format('CREATE TABLE public.support_tickets (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id TEXT NOT NULL,
            subject TEXT,
            message TEXT,
            status TEXT DEFAULT ''OPEN'',
            order_id %s REFERENCES public.orders(id),
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        )', order_id_type);
    END IF;

    -- SETTLEMENTS
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'settlements') THEN
        EXECUTE format('CREATE TABLE public.settlements (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            vendor_id %s REFERENCES public.vendors(id),
            amount NUMERIC(10,2),
            fee_deducted NUMERIC(10,2),
            gst_deducted NUMERIC(10,2),
            status TEXT DEFAULT ''PENDING'',
            payout_date TIMESTAMP WITH TIME ZONE,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        )', vendor_id_type);
    END IF;

    -- 4. VENDOR LOCATION LOGIC
    ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS latitude NUMERIC(10,8);
    ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS longitude NUMERIC(11,8);
    ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS delivery_radius_km INTEGER DEFAULT 15;

END $$;

-- 5. REAL-TIME BROADCAST (Standalone to avoid nesting transaction issues)
DO $$
DECLARE
    tbl_name TEXT;
    target_tables TEXT[] := ARRAY['order_items', 'transactions', 'refunds', 'support_tickets', 'settlements'];
BEGIN
    FOREACH tbl_name IN ARRAY target_tables LOOP
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = tbl_name) THEN
            EXECUTE format('ALTER TABLE public.%I REPLICA IDENTITY FULL', tbl_name);
            BEGIN
                EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', tbl_name);
            EXCEPTION WHEN OTHERS THEN NULL;
            END;
        END IF;
    END LOOP;
END $$;

COMMIT;

NOTIFY pgrst, 'reload schema';
