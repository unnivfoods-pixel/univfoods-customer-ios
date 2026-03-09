-- 🔗 THE MISSING LINKS: DATABASE RELATIONSHIP REPAIR
-- This script fixes the "Disconnected" feeling by establishing hard foreign keys.
-- Without these, the Admin Panel cannot join tables to show names (e.g., Vendor Name for a Product).

BEGIN;

-- 1. IDENTIFY & FIX PRODUCTS -> VENDORS
-- If 'vendor_id' exists but is not a foreign key, the join 'vendors(name)' will fail.
DO $$
BEGIN
    -- Check if vendor_id column exists
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'vendor_id') THEN
        -- Add foreign key if not exists
        IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'fk_products_vendors') THEN
            ALTER TABLE public.products 
            ADD CONSTRAINT fk_products_vendors 
            FOREIGN KEY (vendor_id) REFERENCES public.vendors(id) ON DELETE CASCADE;
        END IF;
    END IF;
END $$;

-- 2. IDENTIFY & FIX ORDERS -> VENDORS
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'vendor_id') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'fk_orders_vendors') THEN
            ALTER TABLE public.orders 
            ADD CONSTRAINT fk_orders_vendors 
            FOREIGN KEY (vendor_id) REFERENCES public.vendors(id) ON DELETE SET NULL;
        END IF;
    END IF;
END $$;

-- 3. IDENTIFY & FIX ORDERS -> RIDERS
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'rider_id') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'fk_orders_riders') THEN
            ALTER TABLE public.orders 
            ADD CONSTRAINT fk_orders_riders 
            FOREIGN KEY (rider_id) REFERENCES public.delivery_riders(id) ON DELETE SET NULL;
        END IF;
    END IF;
END $$;

-- 4. IDENTIFY & FIX ORDERS -> CUSTOMERS
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'customer_id') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'fk_orders_customers') THEN
            ALTER TABLE public.orders 
            ADD CONSTRAINT fk_orders_customers 
            FOREIGN KEY (customer_id) REFERENCES public.customer_profiles(id) ON DELETE SET NULL;
        END IF;
    END IF;
END $$;

-- 5. ENSURE PUBLIC VISIBILITY FOR THE JOINED NAMES
-- If the Admin can see products but not the linked vendor, the row might still fail due to RLS on vendors.
ALTER TABLE public.vendors ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Names are public for joins" ON public.vendors;
CREATE POLICY "Names are public for joins" 
ON public.vendors FOR SELECT 
TO public 
USING (true);

ALTER TABLE public.customer_profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Names are public for joins" ON public.customer_profiles;
CREATE POLICY "Names are public for joins" 
ON public.customer_profiles FOR SELECT 
TO public 
USING (true);

ALTER TABLE public.delivery_riders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Names are public for joins" ON public.delivery_riders;
CREATE POLICY "Names are public for joins" 
ON public.delivery_riders FOR SELECT 
TO public 
USING (true);

COMMIT;

-- Critical for PostgREST cache refresh
NOTIFY pgrst, 'reload schema';
