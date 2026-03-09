-- 🛰️ COMPLETE REALTIME TRACKING ENGINE (MASTER V6)
-- Implements event-driven GPS tracking, smooth animations, and geofence validation.

BEGIN;

-- 1. TRACKING HISTORY TABLE (Nuclear IDs: TEXT)
CREATE TABLE IF NOT EXISTS public.order_tracking (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id TEXT NOT NULL,
    rider_id TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    speed DOUBLE PRECISION DEFAULT 0,
    heading DOUBLE PRECISION DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Index for fast retrieval in Customer App
CREATE INDEX IF NOT EXISTS idx_order_tracking_order_id ON public.order_tracking(order_id);

-- 2. UNIVERSAL RIDER LOCATION UPDATE (The Heartbeat)
CREATE OR REPLACE FUNCTION public.update_rider_location_v3(
    p_order_id TEXT,
    p_rider_id TEXT,
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION,
    p_speed DOUBLE PRECISION DEFAULT 0,
    p_heading DOUBLE PRECISION DEFAULT 0
)
RETURNS VOID AS $$
DECLARE
    v_target_lat DOUBLE PRECISION;
    v_target_lng DOUBLE PRECISION;
    v_status TEXT;
    v_dist_km DOUBLE PRECISION;
    v_eta_mins INTEGER;
BEGIN
    -- 1. Fetch Current Order Context
    SELECT status, delivery_lat, delivery_lng 
    INTO v_status, v_target_lat, v_target_lng
    FROM public.orders WHERE id::text = p_order_id;

    -- Only allow tracking if order is PICKED_UP
    -- Note: Users rule says "Tracking must start ONLY when PICKED_UP"
    IF v_status != 'picked_up' AND v_status != 'PICKED_UP' THEN
        RETURN;
    END IF;

    -- 2. Calculate Distance & ETA (Event-driven intelligence)
    IF v_target_lat IS NOT NULL THEN
        v_dist_km := ST_Distance(
            ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
            ST_SetSRID(ST_MakePoint(v_target_lng, v_target_lat), 4326)::geography
        ) / 1000.0;
        
        -- ETA: 25km/h avg speed + 2m buffer
        v_eta_mins := ceil((v_dist_km / 25.0) * 60) + 2;
    END IF;

    -- 3. Update Order Realtime Pulse
    UPDATE public.orders
    SET 
        current_lat = p_lat,
        current_lng = p_lng,
        speed = p_speed,
        heading = p_heading,
        distance_remaining_km = v_dist_km,
        eta_minutes = v_eta_mins,
        last_gps_update = now()
    WHERE id::text = p_order_id;

    -- 4. Update Rider Global Dashboard Registry
    -- (Helps Admin see where riders are even without active orders)
    UPDATE public.delivery_riders
    SET 
        current_lat = p_lat,
        current_lng = p_lng,
        last_gps_update = now(),
        is_online = true
    WHERE id::text = p_rider_id;

    -- 5. Broadcast to History (Triggers Realtime Subscription in Apps)
    INSERT INTO public.order_tracking (order_id, rider_id, latitude, longitude, speed, heading)
    VALUES (p_order_id, p_rider_id, p_lat, p_lng, p_speed, p_heading);

    -- 6. Abnormal Speed Safety (Optional Rule check)
    -- If p_speed > 120 (fake GPS check), we could flag it here.
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. GEOFENCED DELIVERY VALIDATION (The Secure Delivery OTP)
CREATE OR REPLACE FUNCTION public.verify_order_otp_v3(
    p_order_id TEXT,
    p_otp TEXT,
    p_type TEXT -- 'pickup' or 'delivery'
)
RETURNS JSONB AS $$
DECLARE
    v_correct_otp TEXT;
    v_r_lat DOUBLE PRECISION;
    v_r_lng DOUBLE PRECISION;
    v_t_lat DOUBLE PRECISION;
    v_t_lng DOUBLE PRECISION;
    v_dist_m DOUBLE PRECISION;
    v_status TEXT;
BEGIN
    -- INIT
    SELECT status, pickup_otp, delivery_otp, current_lat, current_lng, delivery_lat, delivery_lng 
    INTO v_status, v_correct_otp, v_correct_otp, v_r_lat, v_r_lng, v_t_lat, v_t_lng
    FROM public.orders WHERE id::text = p_order_id;
    
    -- Pick correct OTP column
    IF p_type = 'pickup' THEN
        SELECT pickup_otp INTO v_correct_otp FROM public.orders WHERE id::text = p_order_id;
    ELSE
        SELECT delivery_otp INTO v_correct_otp FROM public.orders WHERE id::text = p_order_id;
    END IF;

    -- Verification
    IF v_correct_otp != p_otp THEN
        RETURN jsonb_build_object('success', false, 'message', 'INVALID_OTP');
    END IF;

    -- Proximity Check for Delivery (100 Meters)
    IF p_type = 'delivery' THEN
        IF v_r_lat IS NOT NULL AND v_t_lat IS NOT NULL THEN
            v_dist_m := ST_Distance(
                ST_SetSRID(ST_MakePoint(v_r_lng, v_r_lat), 4326)::geography,
                ST_SetSRID(ST_MakePoint(v_t_lng, v_t_lat), 4326)::geography
            );
            
            IF v_dist_m > 100 THEN
                RETURN jsonb_build_object(
                    'success', false, 
                    'message', 'PROXIMITY_FAULT', 
                    'distance_m', floor(v_dist_m)
                );
            END IF;
        END IF;
    END IF;

    -- Success -> Transition Status
    IF p_type = 'pickup' THEN
        UPDATE public.orders SET status = 'picked_up', last_gps_update = now() WHERE id::text = p_order_id;
    ELSE
        UPDATE public.orders SET status = 'delivered', last_gps_update = now(), is_settled = true WHERE id::text = p_order_id;
        -- Release rider
        UPDATE public.delivery_riders SET active_order_id = NULL WHERE active_order_id::text = p_order_id;
    END IF;

    RETURN jsonb_build_object('success', true, 'message', 'VERIFIED');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. PERMISSIONS & REALTIME BROADCAST
GRANT EXECUTE ON FUNCTION public.update_rider_location_v3 TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.verify_order_otp_v3 TO anon, authenticated;

-- Ensure Realtime handles the tracking table
ALTER TABLE public.order_tracking REPLICA IDENTITY FULL;
-- Rebuild publication to include new table
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

COMMIT;

NOTIFY pgrst, 'reload schema';
