-- Fix RLS Policy Collision & Enable Tracking
-- Run this in Supabase SQL Editor

-- 1. Reset Policies on delivery_riders
ALTER TABLE delivery_riders DISABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public read access for delivery_riders" ON delivery_riders;
DROP POLICY IF EXISTS "Riders can update own location" ON delivery_riders;
DROP POLICY IF EXISTS "Riders can update own location " ON delivery_riders; -- Catch trailing space typo if any

ALTER TABLE delivery_riders ENABLE ROW LEVEL SECURITY;

-- 2. Create Policies (Clean Slate)
CREATE POLICY "Public read access for delivery_riders"
ON delivery_riders FOR SELECT
USING (true);

CREATE POLICY "Riders can update own location"
ON delivery_riders FOR UPDATE
USING (auth.uid() = id);

-- 3. Ensure rider_tracking is accessible
ALTER TABLE rider_tracking ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Riders can insert tracking logs" ON rider_tracking;
DROP POLICY IF EXISTS "Admins/Customers read tracking logs" ON rider_tracking;

CREATE POLICY "Riders can insert tracking logs"
ON rider_tracking FOR INSERT
WITH CHECK (auth.uid() = rider_id);

CREATE POLICY "Admins/Customers read tracking logs"
ON rider_tracking FOR SELECT
USING (true);
