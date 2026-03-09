-- 🚚 THE ULTIMATE REALTIME TRACKING ENGINE
-- Follows the strict architecture: 5s GPS, order-based tracking, Smooth UI events.

BEGIN;

-- 1. EXTEND ORDERS TABLE
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS current_lat double precision,
ADD COLUMN IF NOT EXISTS current_lng double precision,
ADD COLUMN IF NOT EXISTS last_gps_update timestamptz,
ADD COLUMN IF NOT EXISTS speed double precision DEFAULT 0,
ADD COLUMN IF NOT EXISTS heading double precision DEFAULT 0,
ADD COLUMN IF NOT EXISTS distance_remaining_km double precision DEFAULT 0,
ADD COLUMN IF NOT EXISTS eta_minutes integer DEFAULT 0;

-- 2. CREATE ORDER TRACKING HISTORY (For security and history audit)
CREATE TABLE IF NOT EXISTS public.order_tracking (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id text NOT NULL, -- TEXT to match the converted ID system
    rider_id text NOT NULL,
    latitude double precision NOT NULL,
    longitude double precision NOT NULL,
    speed double precision DEFAULT 0,
    heading double precision DEFAULT 0,
    created_at timestamptz DEFAULT now()
);

-- 3. ENABLE REALTIME ON CORE TABLES
-- Use REPLICA IDENTITY FULL to ensure all columns are sent in the UPDATE event
ALTER TABLE public.orders REPLICA IDENTITY FULL;
-- ALTER TABLE public.order_tracking REPLICA IDENTITY FULL; -- Actually tracking history might not need FULL identity if we only insert

-- Ensure they are in the publication
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'order_tracking') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.order_tracking;
    END IF;
END $$;

-- 4. MASTER RPC: UPDATE RIDER LOCATION
-- This is called by the Delivery App every 5 seconds only when PICKED_UP
CREATE OR REPLACE FUNCTION public.update_rider_location_v3(
    p_order_id text,
    p_rider_id text,
    p_lat double precision,
    p_lng double precision,
    p_speed double precision DEFAULT 0,
    p_heading double precision DEFAULT 0,
    p_dist_rem double precision DEFAULT 0,
    p_eta_min integer DEFAULT 0
)
RETURNS void AS $$
DECLARE
    v_status text;
BEGIN
    -- Check if order status is trackable
    SELECT status INTO v_status FROM public.orders WHERE id::text = p_order_id;
    
    -- ONLY update if order is in a trackable state
    IF v_status IN ('picked_up', 'on_the_way', 'PICKED_UP', 'ON_THE_WAY') THEN
        -- A. Update the Order record (Realtime event for Customer/Admin)
        UPDATE public.orders
        SET 
            current_lat = p_lat,
            current_lng = p_lng,
            speed = p_speed,
            heading = p_heading,
            distance_remaining_km = p_dist_rem,
            eta_minutes = p_eta_min,
            last_gps_update = now()
        WHERE id::text = p_order_id;
        
        -- B. Also update the Global Rider location (For general rider discovery/admin map)
        UPDATE public.delivery_riders
        SET 
            current_lat = p_lat,
            current_lng = p_lng,
            heading = p_heading,
            updated_at = now()
        WHERE id::text = p_rider_id;

        -- C. Log to movement history (every 5 seconds)
        INSERT INTO public.order_tracking (order_id, rider_id, latitude, longitude, speed, heading)
        VALUES (p_order_id, p_rider_id, p_lat, p_lng, p_speed, p_heading);
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. PERMISSIONS
GRANT EXECUTE ON FUNCTION public.update_rider_location_v3 TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.order_tracking TO anon, authenticated, service_role;

NOTIFY pgrst, 'reload schema';

COMMIT;
