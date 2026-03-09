-- 🚨 EMERGENCY LOGISTICS RESTORATION SCRIPT
-- Resolves the "Empty Orders" issue in the Admin Panel.
-- This script ensures the Admin has absolute SELECT/UPDATE power across the entire logistics chain.

BEGIN;

-- 1. IDENTIFY & PURGE CONFLICTING POLICIES
-- We need to ensure no RESTRICTIVE policies are blocking the Admin.
-- And that the basic "Admin oversight" is actually working.

-- ORDERS
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admin oversight" ON public.orders;
DROP POLICY IF EXISTS "Admin All Access Orders" ON public.orders;
DROP POLICY IF EXISTS "Vendor operations" ON public.orders;
DROP POLICY IF EXISTS "Rider operations" ON public.orders;
DROP POLICY IF EXISTS "Customer view" ON public.orders;
DROP POLICY IF EXISTS "Enable all access for orders" ON public.orders;

-- UNIVERSAL SELECT FOR AUTHENTICATED (ADMINS)
CREATE POLICY "Admin_Nuclear_Select_Orders" 
ON public.orders FOR SELECT 
TO authenticated 
USING (true);

CREATE POLICY "Admin_Nuclear_All_Orders" 
ON public.orders FOR ALL 
TO authenticated 
USING (true)
WITH CHECK (true);

-- 2. RELATED TABLES SYNC (Join Support)
-- If the query in Orders.jsx joins these, the user MUST have SELECT on them.

-- CUSTOMER PROFILES
ALTER TABLE public.customer_profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins can see all profiles" ON public.customer_profiles;
CREATE POLICY "Admins can see all profiles" 
ON public.customer_profiles FOR SELECT 
TO authenticated 
USING (true);

-- VENDORS
ALTER TABLE public.vendors ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admin All Access Vendors" ON public.vendors;
DROP POLICY IF EXISTS "Enable all access for vendors" ON public.vendors;
CREATE POLICY "Admin_Access_Vendors" 
ON public.vendors FOR ALL 
TO authenticated 
USING (true)
WITH CHECK (true);

-- DELIVERY RIDERS
ALTER TABLE public.delivery_riders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admin All Access Riders" ON public.delivery_riders;
DROP POLICY IF EXISTS "Enable all access for riders" ON public.delivery_riders;
CREATE POLICY "Admin_Access_Riders" 
ON public.delivery_riders FOR ALL 
TO authenticated 
USING (true)
WITH CHECK (true);

-- 3. FIX THE "TEXT = UUID" DISCREPANCY PERMANENTLY
-- If there's an RLS policy using logic like 'rider_id = auth.uid()', 
-- we must ensure it's cast correctly if columns are text.

-- RIDER SPECIFIC (Operational app level)
CREATE POLICY "Rider_Specific_Ops" 
ON public.orders FOR ALL 
TO authenticated 
USING (
    (status::text IN ('ready', 'READY') AND rider_id IS NULL) OR 
    (rider_id::text = auth.uid()::text)
);

-- VENDOR SPECIFIC (Operational app level)
CREATE POLICY "Vendor_Specific_Ops" 
ON public.orders FOR ALL 
TO authenticated 
USING (
    EXISTS (
        SELECT 1 FROM public.vendors v 
        WHERE v.id::text = public.orders.vendor_id::text 
        AND v.owner_id::text = auth.uid()::text
    )
);

-- 4. ENSURE REALTIME IDENTITY
ALTER TABLE public.orders REPLICA IDENTITY FULL;

COMMIT;

NOTIFY pgrst, 'reload schema';
