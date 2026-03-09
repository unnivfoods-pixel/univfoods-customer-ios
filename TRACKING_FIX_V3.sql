-- FIX: Create missing rider_tracking table and Reset RLS
-- Run this in Supabase SQL Editor

-- 1. Create table if not exists
CREATE TABLE IF NOT EXISTS rider_tracking (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id UUID, -- Can be null if just roaming
    rider_id UUID NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT now(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 2. Reset Policies on delivery_riders (Fix Collision)
ALTER TABLE delivery_riders DISABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public read access for delivery_riders" ON delivery_riders;
DROP POLICY IF EXISTS "Riders can update own location" ON delivery_riders;
DROP POLICY IF EXISTS "Riders can update own location " ON delivery_riders; 

ALTER TABLE delivery_riders ENABLE ROW LEVEL SECURITY;

-- 3. Create Policies for delivery_riders
CREATE POLICY "Public read access for delivery_riders"
ON delivery_riders FOR SELECT
USING (true);

CREATE POLICY "Riders can update own location"
ON delivery_riders FOR UPDATE
USING (auth.uid() = id);

-- 4. Enable RLS on rider_tracking
ALTER TABLE rider_tracking ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Riders can insert tracking logs" ON rider_tracking;
DROP POLICY IF EXISTS "Admins/Customers read tracking logs" ON rider_tracking;

-- 5. Create Policies for rider_tracking
CREATE POLICY "Riders can insert tracking logs"
ON rider_tracking FOR INSERT
WITH CHECK (auth.uid() = rider_id);

CREATE POLICY "Admins/Customers read tracking logs"
ON rider_tracking FOR SELECT
USING (true);
