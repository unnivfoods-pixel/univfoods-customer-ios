/*
REALTIME ACTION PATCH (V12)
---------------------------
1. Ensures all operational tables (orders, products, vendors) have realtime enabled.
2. Fixes RLS policies to allow Vendors to manage THEIR OWN data.
3. Adds any missing columns for pro features.
*/

-- 1. Ensure columns exist
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS vendor_id UUID REFERENCES public.vendors(id) ON DELETE CASCADE;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS is_available BOOLEAN DEFAULT true;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'General';
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS calories TEXT;

-- 2. Realtime publication fix
-- Some tables might not be in the publication yet
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'orders') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'products') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.products;
    END IF;
END $$;

-- 3. RLS - Empowering Vendors
-- Vendors need to be able to:
-- - See their own profile
-- - Update their status (open/closed)
-- - CRUD their own menu/products
-- - Update their own orders

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

-- Policy for Vendors to manage THEIR OWN products
DROP POLICY IF EXISTS "Vendors manage own products" ON public.products;
CREATE POLICY "Vendors manage own products" ON public.products
FOR ALL USING (
    EXISTS (
        SELECT 1 FROM public.vendors v 
        WHERE v.id = public.products.vendor_id 
        AND v.owner_id = auth.uid()
    )
);

-- Policy for Public to see all available products (for Customer App)
DROP POLICY IF EXISTS "Public view products" ON public.products;
CREATE POLICY "Public view products" ON public.products
FOR SELECT USING (is_available = true);

-- Policy for Vendors to manage THEIR OWN orders
DROP POLICY IF EXISTS "Vendors manage own orders" ON public.orders;
CREATE POLICY "Vendors manage own orders" ON public.orders
FOR ALL USING (
    EXISTS (
        SELECT 1 FROM public.vendors v 
        WHERE v.id = public.orders.vendor_id 
        AND v.owner_id = auth.uid()
    )
);

-- Policy for Vendors to manage THEIR OWN profile
DROP POLICY IF EXISTS "Vendors manage own profile" ON public.vendors;
CREATE POLICY "Vendors manage own profile" ON public.vendors
FOR ALL USING (owner_id = auth.uid());

-- 4. Audit Log
INSERT INTO public.app_settings (key, value) 
VALUES ('system_info', jsonb_build_object('last_refresh', now(), 'status', 'ACTIONS_ENABLED', 'version', 'V12'))
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

NOTIFY pgrst, 'reload schema';
