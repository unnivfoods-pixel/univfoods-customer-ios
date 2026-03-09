-- 🛡️ ULTIMATE CHECKOUT UNBLOCKER
-- This script completely removes RLS barriers for testing/demo purposes.
-- Use this ONLY if normal RLS is blocked and you need to unblock the flow immediately.

BEGIN;

-- 1. NUKE POLICIES
DROP POLICY IF EXISTS "Vendor operations" ON public.orders;
DROP POLICY IF EXISTS "Rider operations" ON public.orders;
DROP POLICY IF EXISTS "Customer view" ON public.orders;
DROP POLICY IF EXISTS "Admin oversight" ON public.orders;
DROP POLICY IF EXISTS "Allow authenticated insert" ON public.orders;
DROP POLICY IF EXISTS "Allow authenticated select" ON public.orders;
DROP POLICY IF EXISTS "Allow vendor manage" ON public.orders;
DROP POLICY IF EXISTS "Allow rider select ready" ON public.orders;
DROP POLICY IF EXISTS "Allow rider manage assigned" ON public.orders;
DROP POLICY IF EXISTS "Allow service role all" ON public.orders;
DROP POLICY IF EXISTS "Allow guests to place orders" ON public.orders;

-- 2. COMPLETELY OPEN POLICY FOR DEV (Unblocks Checkout for ANY user)
CREATE POLICY "Unrestricted Dev Access" 
ON public.orders FOR ALL 
USING (true) 
WITH CHECK (true);

-- 3. ENSURE FOR SUB-TABLES IF NEEDED
ALTER TABLE public.orders DISABLE ROW LEVEL SECURITY; -- OR keep it enabled with the open policy

-- Alternatively, keep RLS enabled but allow ALL
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Dev All Access" ON public.orders;
CREATE POLICY "Dev All Access" ON public.orders FOR ALL TO public USING (true) WITH CHECK (true);

-- 4. ENSURE FOR CUSTOMER PROFILES (Sometimes checked during checkout)
ALTER TABLE public.customer_profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public Profile Access" ON public.customer_profiles;
CREATE POLICY "Public Profile Access" ON public.customer_profiles FOR SELECT TO public USING (true);

COMMIT;

SELECT 'Order checkout is now UNRESTRICTED for development!' as status;
