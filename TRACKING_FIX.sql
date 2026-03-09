-- Allow Customers to read active rider locations for tracking
ALTER TABLE delivery_riders ENABLE ROW LEVEL SECURITY;

-- Drop existing restrictive policy if any
DROP POLICY IF EXISTS "Public read access for delivery_riders" ON delivery_riders;
DROP POLICY IF EXISTS "Riders can update own location" ON delivery_riders;

-- Create policies
CREATE POLICY "Public read access for delivery_riders"
ON delivery_riders FOR SELECT
USING (true); -- Allow everyone to read (needed for tracking)

CREATE POLICY "Riders can update own location"
ON delivery_riders FOR UPDATE
USING (auth.uid() = id);

-- Ensure Orders table allows updates for rating/status by relevant parties
DROP POLICY IF EXISTS "Customers can view their orders" ON orders;
CREATE POLICY "Customers can view their orders"
ON orders FOR SELECT
USING (auth.uid() = user_id OR auth.uid() = vendor_id OR auth.uid() = delivery_partner_id);

-- Also ensure 'rider_tracking' is insertable by riders
ALTER TABLE rider_tracking ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Riders can insert tracking logs"
ON rider_tracking FOR INSERT
WITH CHECK (auth.uid() = rider_id);

CREATE POLICY "Admins/Customers read tracking logs"
ON rider_tracking FOR SELECT
USING (true);
