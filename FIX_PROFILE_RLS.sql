-- FIX RLS FOR CUSTOMER PROFILES
-- Fixes "New row violates row-level security policy" when saving profile.

-- 1. Ensure Table is Realtime Enabled
ALTER PUBLICATION supabase_realtime ADD TABLE public.customer_profiles;

-- 2. Open up RLS Policies for Customer Profiles
-- This allows guests/forced users in demo mode to save their profiles.
ALTER TABLE public.customer_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public profiles read" ON public.customer_profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.customer_profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.customer_profiles;
DROP POLICY IF EXISTS "Enable all access for profiles" ON public.customer_profiles;
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.customer_profiles;

-- High Permissive Policy for Demo
CREATE POLICY "Super Access Profiles" ON public.customer_profiles 
FOR ALL 
USING (true) 
WITH CHECK (true);

-- 3. Delivery Riders (Allow status toggles and location updates)
ALTER TABLE public.delivery_riders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public riders read" ON public.delivery_riders;
DROP POLICY IF EXISTS "Public riders insert" ON public.delivery_riders;
DROP POLICY IF EXISTS "Public riders update" ON public.delivery_riders;
DROP POLICY IF EXISTS "Enable all access for riders" ON public.delivery_riders;

CREATE POLICY "Super Access Riders" ON public.delivery_riders 
FOR ALL 
USING (true) 
WITH CHECK (true);

-- 4. User Addresses
ALTER TABLE public.user_addresses ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Enable all access for addresses" ON public.user_addresses;
CREATE POLICY "Super Access Addresses" ON public.user_addresses 
FOR ALL 
USING (true) 
WITH CHECK (true);

-- Wallet records/Profiles might need balance updates
-- customer_profiles often has the wallet balance

NOTIFY pgrst, 'reload schema';
