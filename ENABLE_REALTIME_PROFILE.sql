-- ==========================================
-- ENABLE REALTIME FOR PROFILE & ADDRESSES
-- ==========================================

-- 1. Enable Realtime for customer_profiles
BEGIN;
  -- Check if publication exists, if not create it (standard 'supabase_realtime')
  -- Usually it exists. We just add tables to it.
  
  -- Remove first to avoid duplicates/errors if already added
  ALTER PUBLICATION supabase_realtime DROP TABLE IF EXISTS public.customer_profiles;
  ALTER PUBLICATION supabase_realtime DROP TABLE IF EXISTS public.user_addresses;

  -- Add tables to publication
  ALTER PUBLICATION supabase_realtime ADD TABLE public.customer_profiles;
  ALTER PUBLICATION supabase_realtime ADD TABLE public.user_addresses;
COMMIT;

-- 2. Verify RLS Policies allow Realtime
-- Realtime respects RLS. Ensure 'Select' is allowed for public/anon (which we did in previous scripts, but let's double check)

-- Ensure public can read profiles (for now, to fix the issue)
DROP POLICY IF EXISTS "Allow public read" ON public.customer_profiles;
CREATE POLICY "Allow public read" ON public.customer_profiles FOR SELECT USING (true);

-- Ensure public can read addresses
DROP POLICY IF EXISTS "Allow public read addresses" ON public.user_addresses;
CREATE POLICY "Allow public read addresses" ON public.user_addresses FOR SELECT USING (true);

-- 3. Notify
NOTIFY pgrst, 'reload config';
