-- ==========================================================
-- 🏆 MASTER ORDER MANAGEMENT ENGINE (V3)
-- ==========================================================
-- Implements state transitions, OTP security, distance validation, 
-- and real-time synchronization for Customer, Vendor, and Delivery.

BEGIN;

-- 1. EXTEND ORDERS TABLE FOR FULL LIFECYCLE
-- Ensure all required columns exist for the master flow
DO $$ 
BEGIN
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_lat DOUBLE PRECISION;
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_lng DOUBLE PRECISION;
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS pickup_lat DOUBLE PRECISION;
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS pickup_lng DOUBLE PRECISION;
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS pickup_otp TEXT;
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_otp TEXT;
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_address_id UUID;
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS cooking_instructions TEXT;
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_partner_id UUID REFERENCES public.delivery_riders(id);
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS current_lat DOUBLE PRECISION; -- Rider live lat
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS current_lng DOUBLE PRECISION; -- Rider live lng
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS distance_remaining_km DOUBLE PRECISION;
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS eta_minutes INTEGER;
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS last_gps_update TIMESTAMP WITH TIME ZONE;
END $$;

-- 2. MASTER ORDER PLACEMENT RPC
-- Use this instead of direct inserts for better control.
CREATE OR REPLACE FUNCTION public.place_order_v3(
    p_customer_id TEXT,
    p_vendor_id UUID,
    p_items JSONB,
    p_total DOUBLE PRECISION,
    p_address TEXT,
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION,
    p_payment_method TEXT DEFAULT 'COD',
    p_instructions TEXT DEFAULT '',
    p_address_id UUID DEFAULT NULL,
    p_payment_status TEXT DEFAULT 'PENDING',
    p_payment_id TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_order_id UUID;
    v_v_lat DOUBLE PRECISION;
    v_v_lng DOUBLE PRECISION;
    v_v_radius DOUBLE PRECISION;
    v_v_status TEXT;
    v_dist DOUBLE PRECISION;
    v_pickup_otp TEXT;
    v_delivery_otp TEXT;
BEGIN
    -- A. Fetch Vendor Stats
    SELECT latitude, longitude, COALESCE(delivery_radius_km, 15.0), status 
    INTO v_v_lat, v_v_lng, v_v_radius, v_v_status
    FROM public.vendors WHERE id = p_vendor_id;

    -- B. Validate Vendor Status
    IF v_v_status != 'ONLINE' THEN
        RAISE EXCEPTION 'VENDOR_OFFLINE: This restaurant is currently not accepting orders.';
    END IF;

    -- C. Validate Distance (Safety Check)
    v_dist := ST_Distance(
        ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
        ST_SetSRID(ST_MakePoint(v_v_lng, v_v_lat), 4326)::geography
    ) / 1000.0;

    IF v_dist > v_v_radius THEN
        RAISE EXCEPTION 'OUT_OF_RADIUS: Selected address is %km away. Max allowed is %km.', 
            ROUND(v_dist::numeric, 2), v_v_radius;
    END IF;

    -- D. Generate Secure OTPs
    v_pickup_otp := floor(random() * 9000 + 1000)::text;
    v_delivery_otp := floor(random() * 9000 + 1000)::text;

    -- E. Create Order
    INSERT INTO public.orders (
        customer_id, vendor_id, items, total, address, 
        delivery_lat, delivery_lng, pickup_lat, pickup_lng,
        status, payment_method, payment_status, payment_id,
        pickup_otp, delivery_otp, delivery_address_id, cooking_instructions
    ) VALUES (
        p_customer_id, p_vendor_id, p_items, p_total, p_address, 
        p_lat, p_lng, v_v_lat, v_v_lng,
        'placed', p_payment_method, p_payment_status, p_payment_id,
        v_pickup_otp, v_delivery_otp, p_address_id, p_instructions
    ) RETURNING id INTO v_order_id;

    -- F. Populate Order Items (Permanent Truth)
    INSERT INTO public.order_items (order_id, product_id, name, quantity, price)
    SELECT v_order_id, (item->>'product_id')::uuid, (item->>'name'), (item->>'qty')::int, (item->>'price')::double precision
    FROM jsonb_array_elements(p_items) AS item;

    -- G. Populate Payments (Permanent Truth)
    IF p_payment_status = 'paid' OR p_payment_status = 'PAID' THEN
        INSERT INTO public.payments (order_id, user_id, payment_method, transaction_id, amount, status)
        VALUES (v_order_id, p_customer_id, p_payment_method, p_payment_id, p_total, 'SUCCESS');
    END IF;

    RETURN v_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. UNIFIED STATUS TRANSITION LOGIC
-- Handles all updates with specific side-effects
CREATE OR REPLACE FUNCTION public.update_order_status_v3(
    p_order_id UUID,
    p_new_status TEXT,
    p_actor_id TEXT DEFAULT NULL -- ID of vendor/rider/admin making the change
)
RETURNS VOID AS $$
DECLARE
    v_current_status TEXT;
    v_vendor_id UUID;
BEGIN
    SELECT status, vendor_id INTO v_current_status, v_vendor_id FROM public.orders WHERE id = p_order_id;

    -- Only update if status is actually changing
    IF v_current_status = p_new_status THEN
        RETURN;
    END IF;

    -- 1. Apply Status
    UPDATE public.orders 
    SET status = p_new_status,
        -- Auto-set is_settled on delivery
        is_settled = CASE WHEN p_new_status = 'delivered' THEN true ELSE is_settled END
    WHERE id = p_order_id;

    -- 2. Trigger Delivery Search when READY
    IF p_new_status = 'ready' THEN
        -- We could trigger auto-assignment here
        PERFORM public.auto_assign_rider_v1(p_order_id);
    END IF;

    -- 3. Release Rider on completion
    IF p_new_status IN ('delivered', 'cancelled') THEN
        UPDATE public.delivery_riders 
        SET active_order_id = NULL 
        WHERE active_order_id = p_order_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. DELIVERY ASSIGNMENT ENGINE
CREATE OR REPLACE FUNCTION public.auto_assign_rider_v1(p_order_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_v_lat DOUBLE PRECISION;
    v_v_lng DOUBLE PRECISION;
    v_rider_id UUID;
BEGIN
    -- Get vendor location
    SELECT pickup_lat, pickup_lng INTO v_v_lat, v_v_lng FROM public.orders WHERE id = p_order_id;

    -- Find nearest free rider within 5km
    SELECT id INTO v_rider_id
    FROM public.delivery_riders
    WHERE is_online = true 
      AND active_order_id IS NULL
      AND ST_Distance(
          ST_SetSRID(ST_MakePoint(current_lng, current_lat), 4326)::geography,
          ST_SetSRID(ST_MakePoint(v_v_lng, v_v_lat), 4326)::geography
      ) / 1000.0 <= 5.0
    ORDER BY ST_Distance(
          ST_SetSRID(ST_MakePoint(current_lng, current_lat), 4326)::geography,
          ST_SetSRID(ST_MakePoint(v_v_lng, v_v_lat), 4326)::geography
    )
    LIMIT 1;

    IF v_rider_id IS NOT NULL THEN
        UPDATE public.orders 
        SET status = 'rider_assigned', 
            delivery_partner_id = v_rider_id
        WHERE id = p_order_id;

        UPDATE public.delivery_riders SET active_order_id = p_order_id WHERE id = v_rider_id;
        RETURN TRUE;
    END IF;

    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- 5. OTP VERIFICATION ENGINE
CREATE OR REPLACE FUNCTION public.verify_order_otp_v3(
    p_order_id UUID,
    p_otp TEXT,
    p_type TEXT -- 'pickup' or 'delivery'
)
RETURNS BOOLEAN AS $$
DECLARE
    v_correct_otp TEXT;
    v_r_lat DOUBLE PRECISION;
    v_r_lng DOUBLE PRECISION;
    v_t_lat DOUBLE PRECISION;
    v_t_lng DOUBLE PRECISION;
    v_dist DOUBLE PRECISION;
BEGIN
    IF p_type = 'pickup' THEN
        SELECT pickup_otp INTO v_correct_otp FROM public.orders WHERE id = p_order_id;
        IF v_correct_otp = p_otp THEN
            PERFORM public.update_order_status_v3(p_order_id, 'picked_up');
            RETURN TRUE;
        END IF;
    ELSIF p_type = 'delivery' THEN
        -- 🎯 PROXIMITY CHECK (100 Meters)
        SELECT delivery_otp, current_lat, current_lng, delivery_lat, delivery_lng 
        INTO v_correct_otp, v_r_lat, v_r_lng, v_t_lat, v_t_lng
        FROM public.orders WHERE id = p_order_id;

        IF v_r_lat IS NOT NULL AND v_t_lat IS NOT NULL THEN
            v_dist := ST_Distance(
                ST_SetSRID(ST_MakePoint(v_r_lng, v_r_lat), 4326)::geography,
                ST_SetSRID(ST_MakePoint(v_t_lng, v_t_lat), 4326)::geography
            ); -- Meters
            
            IF v_dist > 100 THEN
                RAISE EXCEPTION 'PROXIMITY_FAULT: You must be within 100m of the delivery point. Current distance: %m', ROUND(v_dist::numeric, 0);
            END IF;
        END IF;

        IF v_correct_otp = p_otp THEN
            PERFORM public.update_order_status_v3(p_order_id, 'delivered');
            RETURN TRUE;
        END IF;
    END IF;
    
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- 7. RIDER TRACKING ENGINE (Point 13)
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
    v_dist DOUBLE PRECISION;
    v_eta INTEGER;
BEGIN
    -- 1. Get Target (either Vendor for pickup or Customer for delivery)
    SELECT status, delivery_lat, delivery_lng, pickup_lat, pickup_lng
    INTO v_status, v_target_lat, v_target_lng, v_target_lat, v_target_lng -- Temporary swap logic next
    FROM public.orders WHERE id::text = p_order_id;

    -- If rider is assigned but hasn't picked up, targeted to vendor
    IF v_status = 'rider_assigned' THEN
        SELECT pickup_lat, pickup_lng INTO v_target_lat, v_target_lng FROM public.orders WHERE id::text = p_order_id;
    ELSE
        SELECT delivery_lat, delivery_lng INTO v_target_lat, v_target_lng FROM public.orders WHERE id::text = p_order_id;
    END IF;

    -- 2. Calculate Distance & ETA
    v_dist := ST_Distance(
        ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
        ST_SetSRID(ST_MakePoint(v_target_lng, v_target_lat), 4326)::geography
    ) / 1000.0;
    
    v_eta := ceil((v_dist / 30.0) * 60) + 2; -- 30km/h avg + 2m buffer

    -- 3. Update Order Realtime State
    UPDATE public.orders
    SET 
        current_lat = p_lat,
        current_lng = p_lng,
        speed = p_speed,
        heading = p_heading,
        distance_remaining_km = v_dist,
        eta_minutes = v_eta,
        last_gps_update = now()
    WHERE id::text = p_order_id;

    -- 4. Update Rider Global Registry
    UPDATE public.delivery_riders
    SET 
        current_lat = p_lat,
        current_lng = p_lng,
        last_gps_update = now()
    WHERE id::text = p_rider_id;

    -- 5. History logging
    INSERT INTO public.order_tracking (order_id, rider_id, latitude, longitude, speed, heading)
    VALUES (p_order_id::uuid, p_rider_id::uuid, p_lat, p_lng, p_speed, p_heading);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.update_rider_location_v3 TO authenticated;

COMMIT;
