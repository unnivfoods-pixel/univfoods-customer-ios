-- =============================================================================
-- FIX VENDOR PERMISSIONS & ENABLE REALTIME
-- =============================================================================

-- 1. Enable RLS on 'vendors' but ensure policies exist
ALTER TABLE "vendors" ENABLE ROW LEVEL SECURITY;

-- 2. Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "Vendors can view their own profile" ON "vendors";
DROP POLICY IF EXISTS "Vendors can update their own profile" ON "vendors";
DROP POLICY IF EXISTS "Allow insert for onboarding" ON "vendors";

-- 3. Create permissive policies
-- Allow reading own profile
CREATE POLICY "Vendors can view their own profile" ON "vendors"
  FOR SELECT USING (auth.uid() = owner_id);

-- Allow updating own profile
CREATE POLICY "Vendors can update their own profile" ON "vendors"
  FOR UPDATE USING (auth.uid() = owner_id);

-- Allow inserting (for initial setup if needed)
CREATE POLICY "Allow insert for onboarding" ON "vendors"
  FOR INSERT WITH CHECK (auth.uid() = owner_id);

-- 4. Enable Realtime for 'vendors' and 'orders' tables
-- This is critical for the Dashboard streams to work
alter publication supabase_realtime add table vendors;
alter publication supabase_realtime add table orders;

-- 5. Grant permissions to authenticated users
GRANT ALL ON TABLE "vendors" TO authenticated;
GRANT ALL ON TABLE "vendors" TO service_role;
