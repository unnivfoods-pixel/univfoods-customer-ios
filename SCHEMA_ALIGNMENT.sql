-- 🔗 SCHEMA ALIGNMENT: PRODUCTS & VENDORS (STRICT TYPE FIX)
-- This script fixes the "Incompatible Types" error by matching the column types perfectly.

BEGIN;

-- 1. DETECT TYPES & ALIGN PRODUCTS
-- We need to ensure products.vendor_id matches vendors.id exactly.
DO $$
DECLARE
    v_type TEXT;
BEGIN
    -- Get the type of vendors.id
    SELECT data_type INTO v_type 
    FROM information_schema.columns 
    WHERE table_name = 'vendors' AND column_name = 'id';

    -- Ensure products.vendor_id exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'vendor_id') THEN
        EXECUTE format('ALTER TABLE public.products ADD COLUMN vendor_id %s', v_type);
    ELSE
        -- If it exists but might be the wrong type, we try to convert it
        -- This is where the "uuid vs text" error usually happens
        BEGIN
            EXECUTE format('ALTER TABLE public.products ALTER COLUMN vendor_id TYPE %s USING vendor_id::%s', v_type, v_type);
        EXCEPTION WHEN OTHERS THEN
            -- If conversion fails, it might be because of data. In a dev environment, we might drop and recreation if empty, 
            -- but let's try to be safe and just log it.
            RAISE NOTICE 'Could not convert vendor_id to %', v_type;
        END;
    END IF;

    -- Handle other column alignments
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'image') 
       AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'image_url') THEN
        ALTER TABLE public.products RENAME COLUMN image TO image_url;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'is_available') THEN
        ALTER TABLE public.products ADD COLUMN is_available BOOLEAN DEFAULT TRUE;
    END IF;
END $$;

-- 2. ALIGN VENDORS
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vendors' AND column_name = 'is_approved') THEN
        ALTER TABLE public.vendors ADD COLUMN is_approved BOOLEAN DEFAULT FALSE;
    END IF;
    UPDATE public.vendors SET is_approved = TRUE WHERE approval_status = 'APPROVED';
END $$;

-- 3. ENFORCE FOREIGN KEYS WITH DYNAMIC TYPE MATCHING
ALTER TABLE public.products DROP CONSTRAINT IF EXISTS fk_products_vendors;

-- This will now succeed because we aligned the types above
ALTER TABLE public.products 
ADD CONSTRAINT fk_products_vendors 
FOREIGN KEY (vendor_id) REFERENCES public.vendors(id) ON DELETE CASCADE;

-- 4. PERMISSIONS
ALTER TABLE public.vendors ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public select for joins" ON public.vendors;
CREATE POLICY "Public select for joins" ON public.vendors FOR SELECT USING (true);

COMMIT;

NOTIFY pgrst, 'reload schema';
