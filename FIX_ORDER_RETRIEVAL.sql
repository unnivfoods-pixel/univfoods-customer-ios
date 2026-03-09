-- 🛒 ORDER RETRIEVAL ENHANCEMENT
-- This script adds denormalized vendor data to the orders table.
-- This allows the app to stream orders directly with vendor names/logos, fixing the "No Orders" bug.

BEGIN;

-- 1. ADD COLUMNS FOR REAL-TIME VIEWING
ALTER TABLE IF EXISTS public.orders ADD COLUMN IF NOT EXISTS vendor_name text;
ALTER TABLE IF EXISTS public.orders ADD COLUMN IF NOT EXISTS vendor_logo_url text;
ALTER TABLE IF EXISTS public.orders ADD COLUMN IF NOT EXISTS customer_name text;

-- 2. UPDATE EXISTING ORDERS (One-time sync)
UPDATE public.orders o
SET vendor_name = v.name,
    vendor_logo_url = v.image_url
FROM public.vendors v
WHERE o.vendor_id::text = v.id::text;

UPDATE public.orders o
SET customer_name = cp.full_name
FROM public.customer_profiles cp
WHERE o.customer_id::text = cp.id::text;

-- 3. ENSURE REALTIME IS ENABLED ON THE TABLE (Views don't support streams)
ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;

-- 4. FIX RLS FOR SELECT
-- Ensure users can see their own orders even if the ID is a string/text
DROP POLICY IF EXISTS "Customers can select own orders" ON public.orders;
CREATE POLICY "Customers can select own orders" 
ON public.orders FOR SELECT 
TO public 
USING (customer_id::text = auth.uid()::text OR auth.role() = 'anon');

COMMIT;

SELECT 'Orders table enhanced for Real-time Streaming!' as status;
