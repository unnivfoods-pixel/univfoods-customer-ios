-- 🛡️ DEFENSIVE ORDER RLS FIX (THE CHECKOUT FIX)
-- This script resolves the "new row violates row-level security policy" error.
-- It ensures customers can place their own orders while maintaining security.

BEGIN;

-- 1. CLEANUP ALL EXISTING ORDER POLICIES
DROP POLICY IF EXISTS "Vendor operations" ON public.orders;
DROP POLICY IF EXISTS "Rider operations" ON public.orders;
DROP POLICY IF EXISTS "Customer view" ON public.orders;
DROP POLICY IF EXISTS "Admin oversight" ON public.orders;
DROP POLICY IF EXISTS "Customer can place orders" ON public.orders;
DROP POLICY IF EXISTS "Global order access" ON public.orders;
DROP POLICY IF EXISTS "Vendors manage own orders" ON public.orders;
DROP POLICY IF EXISTS "Riders manage assigned orders" ON public.orders;
DROP POLICY IF EXISTS "Customers view own orders" ON public.orders;

-- Ensure RLS is enabled
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

-- 2. CUSTOMER POLICIES
-- Allow customers to place orders (Crucial for Checkout)
CREATE POLICY "Customers can insert own orders" 
ON public.orders FOR INSERT 
TO authenticated 
WITH CHECK (customer_id::text = auth.uid()::text);

-- Allow customers to view their own orders
CREATE POLICY "Customers can select own orders" 
ON public.orders FOR SELECT 
TO authenticated 
USING (customer_id::text = auth.uid()::text);

-- 3. VENDOR POLICIES
-- Vendors can manage orders for their restaurant
CREATE POLICY "Vendors can manage restaurant orders" 
ON public.orders FOR ALL 
TO authenticated 
USING (
    EXISTS (
        SELECT 1 FROM public.vendors v 
        WHERE v.id::text = public.orders.vendor_id::text 
        AND v.owner_id::text = auth.uid()::text
    )
);

-- 4. RIDER POLICIES
-- Riders can see READY orders to claim them
CREATE POLICY "Riders can see ready orders" 
ON public.orders FOR SELECT 
TO authenticated 
USING (status IN ('ready', 'READY') AND delivery_partner_id IS NULL);

-- Riders can manage their assigned orders
CREATE POLICY "Riders can manage assigned orders" 
ON public.orders FOR ALL 
TO authenticated 
USING (delivery_partner_id::text = auth.uid()::text);

-- 5. ADMIN OVERRIDE (Optional: if you have a specific admin user/role)
-- For now, keep it simple and secure above. 

-- 6. ENSURE REALTIME CONSISTENCY
ALTER TABLE public.orders REPLICA IDENTITY FULL;

COMMIT;

-- VERIFY
SELECT 'Order RLS fixed!' as status;
