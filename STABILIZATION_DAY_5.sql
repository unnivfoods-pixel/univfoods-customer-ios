-- 🚀 DAY 5: GPS & TRACKING ENGINE (CORRECTED)
-- Goal: Solidify live GPS tracking for riders and sharing with customers with cast safety.

BEGIN;

-- 1. High-frequency Realtime Tracking Table
-- This table is tuned for high-velocity updates (every 5-10 seconds)
CREATE TABLE IF NOT EXISTS public.order_live_tracking (
    order_id TEXT PRIMARY KEY, -- Changed to TEXT for compatibility
    rider_id TEXT,
    rider_lat DOUBLE PRECISION NOT NULL,
    rider_lng DOUBLE PRECISION NOT NULL,
    heading DOUBLE PRECISION DEFAULT 0,
    speed DOUBLE PRECISION DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable Realtime for this table
ALTER TABLE public.order_live_tracking REPLICA IDENTITY FULL;

-- 2. Master Tracking RPC
-- This is used by the Delivery App to pulse location
CREATE OR REPLACE FUNCTION public.update_order_tracking_v2(
    p_order_id TEXT,
    p_rider_id TEXT,
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION,
    p_speed DOUBLE PRECISION DEFAULT 0,
    p_heading DOUBLE PRECISION DEFAULT 0
)
RETURNS VOID AS $$
BEGIN
    -- Update the high-frequency table first
    INSERT INTO public.order_live_tracking (
        order_id, rider_id, rider_lat, rider_lng, heading, speed, updated_at
    ) VALUES (
        p_order_id, p_rider_id, p_lat, p_lng, p_heading, p_speed, now()
    )
    ON CONFLICT (order_id) DO UPDATE SET
        rider_lat = EXCLUDED.rider_lat,
        rider_lng = EXCLUDED.rider_lng,
        heading = EXCLUDED.heading,
        speed = EXCLUDED.speed,
        updated_at = now();

    -- Periodically sync to the main 'orders' table for history (Throttled via simple update)
    -- We only update 'orders' if it's been more than 30 seconds to avoid lock contention
    UPDATE public.orders SET
        rider_lat = p_lat,
        rider_lng = p_lng,
        updated_at = now()
    WHERE (id::text) = (p_order_id::text) 
      AND (updated_at < now() - interval '30 seconds' OR updated_at IS NULL);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
