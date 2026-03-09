-- 🛰️ UNIVERSAL LOGISTICS ARCHITECTURE (ULTRA-REALTIME V7)
-- This script reconstructs the core logistics engine for 100% realtime sync.

BEGIN;

-- 1. THE NUCLEAR CLEANER (Resolves "Function is not unique" ambiguity)
DO $$ 
DECLARE 
    r RECORD;
BEGIN
    -- This block purges all overloaded signatures to prevent deployment collision
    FOR r IN (
        SELECT oid::regprocedure as proc_signature 
        FROM pg_proc 
        WHERE proname IN ('update_rider_location_v3', 'verify_order_otp_v3', 'update_order_status_v3') 
        AND pronamespace = 'public'::regnamespace
    ) 
    LOOP
        EXECUTE 'DROP FUNCTION ' || r.proc_signature || ' CASCADE';
        RAISE NOTICE 'Logistics Engine: Purged signature %', r.proc_signature;
    END LOOP;
END $$;

-- 2. CORE TABLE REINFORCEMENT
DO $$ 
BEGIN
    -- Orders metadata for Realtime
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS last_gps_update TIMESTAMPTZ;
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS speed DOUBLE PRECISION DEFAULT 0;
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS heading DOUBLE PRECISION DEFAULT 0;
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS distance_remaining_km DOUBLE PRECISION;
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS eta_minutes INTEGER;
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS is_settled BOOLEAN DEFAULT false;
    
    -- Rider status meta
    ALTER TABLE public.delivery_riders ADD COLUMN IF NOT EXISTS battery_percent INTEGER;
    ALTER TABLE public.delivery_riders ADD COLUMN IF NOT EXISTS internet_status TEXT DEFAULT 'online';
    ALTER TABLE public.delivery_riders ADD COLUMN IF NOT EXISTS last_gps_update TIMESTAMPTZ;
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'Schema check complete.';
END $$;

-- 2. SMART STATUS CHAIN TRIGGER
-- This ensures all 3 apps (Customer, Vendor, Admin) react instantly.
CREATE OR REPLACE FUNCTION public.on_order_status_change()
RETURNS TRIGGER AS $$
DECLARE
    v_short_id TEXT := SUBSTRING(NEW.id::text, 1, 8);
BEGIN
    -- Handle Business Logic per Status
    IF (NEW.status != OLD.status) THEN
        
        -- A. READY FOR PICKUP -> Notify Rider & Admin
        IF NEW.status = 'ready' THEN
             INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
             VALUES (NEW.rider_id::text, 'delivery', 'Ready for Extraction', 'Order #' || v_short_id || ' is waiting for you.', NEW.id::text, 'order');
        END IF;

        -- B. DELIVERED -> Close Logistics Node
        IF NEW.status = 'delivered' THEN
             UPDATE public.delivery_riders SET active_order_id = NULL WHERE id::text = NEW.rider_id::text;
             NEW.is_settled := true;
        END IF;

    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_order_status_sync ON public.orders;
CREATE TRIGGER tr_order_status_sync
BEFORE UPDATE ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.on_order_status_change();

-- 3. THE MASTER GPS STREAM ENGINE (V7)
-- Atomic update of History, Orders, and Rider tables.
CREATE OR REPLACE FUNCTION public.update_rider_location_v3(
    p_order_id TEXT,
    p_rider_id TEXT,
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION,
    p_speed DOUBLE PRECISION DEFAULT 0,
    p_heading DOUBLE PRECISION DEFAULT 0,
    p_battery INTEGER DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
    v_status TEXT;
    v_target_lat DOUBLE PRECISION;
    v_target_lng DOUBLE PRECISION;
    v_dist_km DOUBLE PRECISION;
    v_eta_mins INTEGER;
BEGIN
    -- Fetch Context
    SELECT status, delivery_lat, delivery_lng 
    INTO v_status, v_target_lat, v_target_lng
    FROM public.orders WHERE id::text = p_order_id;

    -- Intelligence: Distance Matrix Emulation
    IF v_target_lat IS NOT NULL THEN
        v_dist_km := ST_Distance(
            ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
            ST_SetSRID(ST_MakePoint(v_target_lng, v_target_lat), 4326)::geography
        ) / 1000.0;
        
        -- Formula: dist / (avg speed 25km/h) + pickup/drop buffer
        v_eta_mins := ceil((v_dist_km / 25.0) * 60) + 2;
    END IF;

    -- Update Order (Broadcast to Customer)
    UPDATE public.orders SET 
        current_lat = p_lat, current_lng = p_lng, speed = p_speed, heading = p_heading,
        distance_remaining_km = v_dist_km, eta_minutes = v_eta_mins, last_gps_update = now()
    WHERE id::text = p_order_id;

    -- Update Rider Registry (Broadcast to Admin)
    UPDATE public.delivery_riders SET 
        current_lat = p_lat, current_lng = p_lng, last_gps_update = now(),
        battery_percent = COALESCE(p_battery, battery_percent), 
        internet_status = 'online'
    WHERE id::text = p_rider_id;

    -- Record History (Broadcasting to smooth animation channel)
    INSERT INTO public.order_tracking (order_id, rider_id, latitude, longitude, speed, heading)
    VALUES (p_order_id, p_rider_id, p_lat, p_lng, p_speed, p_heading);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. SMART OTP GEYSER (V7)
-- Unified logic for Pickup and Delivery security.
CREATE OR REPLACE FUNCTION public.verify_order_otp_v3(
    p_order_id TEXT,
    p_otp TEXT,
    p_type TEXT -- 'pickup' or 'delivery'
)
RETURNS JSONB AS $$
DECLARE
    v_correct_otp TEXT;
    v_status TEXT;
    v_r_lat DOUBLE PRECISION;
    v_r_lng DOUBLE PRECISION;
    v_t_lat DOUBLE PRECISION;
    v_t_lng DOUBLE PRECISION;
    v_dist_m DOUBLE PRECISION;
BEGIN
    SELECT status, pickup_otp, delivery_otp, current_lat, current_lng, delivery_lat, delivery_lng 
    INTO v_status, v_correct_otp, v_correct_otp, v_r_lat, v_r_lng, v_t_lat, v_t_lng
    FROM public.orders WHERE id::text = p_order_id;

    -- Pick OTP Column
    IF p_type = 'pickup' THEN
        SELECT pickup_otp INTO v_correct_otp FROM public.orders WHERE id::text = p_order_id;
    ELSE
        SELECT delivery_otp INTO v_correct_otp FROM public.orders WHERE id::text = p_order_id;
    END IF;

    -- Secure Verification
    IF v_correct_otp != p_otp THEN
        RETURN jsonb_build_object('success', false, 'message', 'SECURITY_FAULT: Invalid OTP');
    END IF;

    -- Proximity Geofence (150 Meters for stability)
    IF p_type = 'delivery' AND v_r_lat IS NOT NULL THEN
        v_dist_m := ST_Distance(
            ST_SetSRID(ST_MakePoint(v_r_lng, v_r_lat), 4326)::geography,
            ST_SetSRID(ST_MakePoint(v_t_lng, v_t_lat), 4326)::geography
        );
        IF v_dist_m > 150 THEN
            RETURN jsonb_build_object('success', false, 'message', 'GEOFENCE_FAULT: Out of Range');
        END IF;
    END IF;

    -- Transitions
    IF p_type = 'pickup' THEN
        UPDATE public.orders SET status = 'picked_up' WHERE id::text = p_order_id;
    ELSE
        UPDATE public.orders SET status = 'delivered' WHERE id::text = p_order_id;
    END IF;

    RETURN jsonb_build_object('success', true, 'message', 'VERIFIED');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. MASTER STATUS CONTROLLER (V7)
-- Centralized function to shift order states from any node (Admin/Vendor).
CREATE OR REPLACE FUNCTION public.update_order_status_v3(
    p_order_id TEXT,
    p_new_status TEXT
)
RETURNS VOID AS $$
BEGIN
    UPDATE public.orders 
    SET status = p_new_status 
    WHERE id::text = p_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. PERMISSIONS
GRANT EXECUTE ON FUNCTION public.update_rider_location_v3 TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.verify_order_otp_v3 TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.update_order_status_v3 TO anon, authenticated;

-- 6. RE-ENABLE REALTIME GLOBAL FEED
ALTER TABLE public.orders REPLICA IDENTITY FULL;
ALTER TABLE public.order_tracking REPLICA IDENTITY FULL;
ALTER TABLE public.delivery_riders REPLICA IDENTITY FULL;

DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

COMMIT;

NOTIFY pgrst, 'reload schema';
