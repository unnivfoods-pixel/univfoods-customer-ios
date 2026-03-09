-- 🛠️ FIX DELIVERY RIDERS RLS
-- Resolves: "new row violates row-level security policy for table 'delivery_riders'" in Admin Panel

BEGIN;

-- 1. Ensure Table exists (it should, but safety first)
CREATE TABLE IF NOT EXISTS public.delivery_riders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT,
    phone TEXT,
    email TEXT,
    is_approved BOOLEAN DEFAULT FALSE,
    kyc_status TEXT DEFAULT 'KYC_PENDING',
    is_online BOOLEAN DEFAULT FALSE,
    current_lat DOUBLE PRECISION,
    current_lng DOUBLE PRECISION,
    status TEXT DEFAULT 'Offline',
    last_online TIMESTAMP WITH TIME ZONE,
    last_location_update TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    active_order_id UUID,
    vehicle_number TEXT,
    heading DOUBLE PRECISION DEFAULT 0
);

-- 2. ENABLE RLS
ALTER TABLE public.delivery_riders ENABLE ROW LEVEL SECURITY;

-- 3. DROP EXISTING POLICIES
DROP POLICY IF EXISTS "Public riders read" ON public.delivery_riders;
DROP POLICY IF EXISTS "Riders can update their own data" ON public.delivery_riders;
DROP POLICY IF EXISTS "Admins can manage all riders" ON public.delivery_riders;
DROP POLICY IF EXISTS "Enable all mission control" ON public.delivery_riders;
DROP POLICY IF EXISTS "Super Access Riders" ON public.delivery_riders;

-- 4. CREATE NEW POLICIES
-- Allow ANYONE to read (for the customer app tracking or admin panel view)
CREATE POLICY "Enable read for everyone" 
ON public.delivery_riders 
FOR SELECT 
USING (true);

-- Allow Admin Panel (authenticated) to manage riders
CREATE POLICY "Super Access Riders" 
ON public.delivery_riders 
FOR ALL 
TO authenticated 
USING (true)
WITH CHECK (true);

-- Allow public insert (if needed for self-registration, though usually via registration_requests)
-- But the admin panel uses explicitly insert into delivery_riders in the "Deploy Unit" modal
CREATE POLICY "Enable insert for authenticated" 
ON public.delivery_riders 
FOR INSERT 
TO authenticated 
WITH CHECK (true);

-- 5. ENSURE REALTIME
ALTER TABLE public.delivery_riders REPLICA IDENTITY FULL;

COMMIT;

NOTIFY pgrst, 'reload schema';
