-- =============================================================================
-- FIX: ADD MISSING user_id COLUMN & ENABLE LIVE TRACKING
-- =============================================================================

-- 1. Ensure user_id exists in delivery_riders (Links to auth.users)
-- This was missing, causing the "column 'user_id' does not exist" error.
ALTER TABLE public.delivery_riders 
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id);

-- 2. Ensure Location Columns exist
ALTER TABLE public.delivery_riders 
ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS heading DOUBLE PRECISION DEFAULT 0.0,
ADD COLUMN IF NOT EXISTS speed DOUBLE PRECISION DEFAULT 0.0,
ADD COLUMN IF NOT EXISTS last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- 3. Reset & Enable Realtime
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR TABLE orders, delivery_riders, vendors, user_addresses;

-- 4. Fix RLS Policies
ALTER TABLE public.delivery_riders ENABLE ROW LEVEL SECURITY;

-- Drop old policies to act fresh
DROP POLICY IF EXISTS "Allow public read of riders for tracking" ON public.delivery_riders;
DROP POLICY IF EXISTS "Riders can update own location" ON public.delivery_riders;

-- Create Public Read Policy
CREATE POLICY "Allow public read of riders for tracking"
ON public.delivery_riders FOR SELECT
USING (true);

-- Create Rider Update Policy (Safe check: user_id must match auth.uid())
CREATE POLICY "Riders can update own location"
ON public.delivery_riders FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- 5. Link existing riders to a dummy user if needed (Optional for testing)
-- UPDATE public.delivery_riders SET user_id = auth.uid() WHERE user_id IS NULL;
