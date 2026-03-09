-- 🚀 COMPLETE ORDER TRACKING FIX (Rider Details + Performance + Chat)
-- Run this in Supabase SQL Editor

-- 1. ENSURE ALL REQUIRED COLUMNS EXIST
ALTER TABLE public.delivery_riders 
ADD COLUMN IF NOT EXISTS current_lat double precision DEFAULT 0,
ADD COLUMN IF NOT EXISTS current_lng double precision DEFAULT 0,
ADD COLUMN IF NOT EXISTS heading double precision DEFAULT 0,
ADD COLUMN IF NOT EXISTS vehicle_number text,
ADD COLUMN IF NOT EXISTS vehicle_type text DEFAULT 'bike',
ADD COLUMN IF NOT EXISTS is_online boolean DEFAULT false;

-- 2. CREATE CHAT MESSAGES TABLE FOR REAL-TIME CHAT
CREATE TABLE IF NOT EXISTS public.chat_messages (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at timestamptz DEFAULT now(),
    order_id uuid REFERENCES public.orders(id) ON DELETE CASCADE,
    sender_id uuid NOT NULL,
    sender_role text NOT NULL, -- 'CUSTOMER', 'RIDER', 'VENDOR'
    message text NOT NULL,
    is_read boolean DEFAULT false,
    attachment_url text
);

-- 3. ENABLE REALTIME FOR CHAT
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages REPLICA IDENTITY FULL;

-- Allow all chat operations (for demo/development)
DROP POLICY IF EXISTS "Allow all chat" ON public.chat_messages;
CREATE POLICY "Allow all chat" ON public.chat_messages FOR ALL USING (true) WITH CHECK (true);

-- 4. UPDATE REALTIME PUBLICATION TO INCLUDE CHAT
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR TABLE 
    public.orders, 
    public.delivery_riders, 
    public.vendors, 
    public.customer_profiles,
    public.notifications,
    public.rider_tracking,
    public.support_tickets,
    public.chat_messages;

-- 5. CREATE INDEXES FOR PERFORMANCE (CRITICAL FOR SMOOTH APP)
CREATE INDEX IF NOT EXISTS idx_orders_customer_status ON public.orders(customer_id, status);
CREATE INDEX IF NOT EXISTS idx_orders_rider_status ON public.orders(delivery_partner_id, status);
CREATE INDEX IF NOT EXISTS idx_orders_vendor_status ON public.orders(vendor_id, status);
CREATE INDEX IF NOT EXISTS idx_chat_order ON public.chat_messages(order_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_rider_location ON public.delivery_riders(id, current_lat, current_lng);
CREATE INDEX IF NOT EXISTS idx_rider_online ON public.delivery_riders(is_online, is_approved);

-- 6. OPTIMIZE DELIVERY_RIDERS TABLE
-- Add missing columns that apps expect
ALTER TABLE public.delivery_riders
ADD COLUMN IF NOT EXISTS profile_image text,
ADD COLUMN IF NOT EXISTS rating numeric DEFAULT 4.5,
ADD COLUMN IF NOT EXISTS total_deliveries integer DEFAULT 0;

-- 7. FUNCTION TO UPDATE RIDER LOCATION (Called by Delivery App)
CREATE OR REPLACE FUNCTION update_rider_location(
    p_rider_id uuid,
    p_lat double precision,
    p_lng double precision,
    p_heading double precision DEFAULT 0
)
RETURNS void AS $$
BEGIN
    UPDATE public.delivery_riders
    SET 
        current_lat = p_lat,
        current_lng = p_lng,
        heading = p_heading,
        updated_at = now()
    WHERE id = p_rider_id;
    
    -- Also log to rider_tracking for history
    INSERT INTO public.rider_tracking (rider_id, latitude, longitude, timestamp)
    VALUES (p_rider_id, p_lat, p_lng, now());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. SAMPLE DATA FOR TESTING (Optional - creates a test rider)
-- Uncomment if you need test data
/*
INSERT INTO public.delivery_riders (
    id, name, phone, email, vehicle_number, vehicle_type, 
    current_lat, current_lng, is_online, is_approved, rating
) VALUES (
    gen_random_uuid(),
    'Test Rider',
    '+919876543210',
    'rider@test.com',
    'TN01AB1234',
    'bike',
    9.5127,
    77.6337,
    true,
    true,
    4.8
) ON CONFLICT DO NOTHING;
*/

-- 9. PERFORMANCE NOTE:
-- VACUUM is automatically managed by Supabase, no manual intervention needed
-- The indexes above will significantly improve query performance

-- ✅ DONE! This will:
-- 1. Fix rider details not showing (proper columns + indexes)
-- 2. Enable real-time chat between customer and rider
-- 3. Improve app performance (indexes + optimizations)
-- 4. Fix vehicle icon display (vehicle_type, vehicle_number columns)
