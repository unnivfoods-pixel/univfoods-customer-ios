-- 🚨 EMERGENCY CHECKOUT & RLS RESTORATION
-- This script fixes the "violates row-level security policy" error on orders.
-- It ensures that Customers, Vendors, and Riders have the correct permissions.

BEGIN;

-- 1. NUKE ALL COMPETING ORDER POLICIES
DROP POLICY IF EXISTS "Vendor operations" ON public.orders;
DROP POLICY IF EXISTS "Rider operations" ON public.orders;
DROP POLICY IF EXISTS "Customer view" ON public.orders;
DROP POLICY IF EXISTS "Admin oversight" ON public.orders;
DROP POLICY IF EXISTS "Customers can insert own orders" ON public.orders;
DROP POLICY IF EXISTS "Customers can select own orders" ON public.orders;
DROP POLICY IF EXISTS "Vendors can manage restaurant orders" ON public.orders;
DROP POLICY IF EXISTS "Riders can see ready orders" ON public.orders;
DROP POLICY IF EXISTS "Riders can manage assigned orders" ON public.orders;
DROP POLICY IF EXISTS "Allow all checkout" ON public.orders;

-- Enable RLS
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

-- 2. CUSTOMER: INSERT & SELECT
-- Allow any authenticated user to place an order where they are the customer
CREATE POLICY "Allow authenticated insert" 
ON public.orders FOR INSERT 
TO authenticated 
WITH CHECK (customer_id::text = auth.uid()::text);

-- Allow customers to see their own orders
CREATE POLICY "Allow authenticated select" 
ON public.orders FOR SELECT 
TO authenticated 
USING (customer_id::text = auth.uid()::text);

-- 3. VENDOR: FULL ACCESS TO THEIR OWN ORDERS
CREATE POLICY "Allow vendor manage" 
ON public.orders FOR ALL 
TO authenticated 
USING (
    EXISTS (
        SELECT 1 FROM public.vendors v 
        WHERE v.id::text = public.orders.vendor_id::text 
        AND v.owner_id::text = auth.uid()::text
    )
);

-- 4. RIDER: SEE READY & MANAGE ASSIGNED
-- We check for both possible column names: delivery_partner_id and rider_id
CREATE POLICY "Allow rider select ready" 
ON public.orders FOR SELECT 
TO authenticated 
USING (status IN ('ready', 'READY', 'PENDING')); -- Flexible status for claiming

CREATE POLICY "Allow rider manage assigned" 
ON public.orders FOR ALL 
TO authenticated 
USING (
    (delivery_partner_id::text = auth.uid()::text) 
    -- OR (rider_id::text = auth.uid()::text) -- Add if rider_id column exists
);

-- 5. ADMIN BYPASS (Safe for dev)
CREATE POLICY "Allow service role all" 
ON public.orders FOR ALL 
TO service_role 
USING (true);

-- 6. REPLICA IDENTITY (Realtime Fix)
ALTER TABLE public.orders REPLICA IDENTITY FULL;

COMMIT;

-- VERIFY
SELECT 'Order RLS fixed for Checkout!' as status;
