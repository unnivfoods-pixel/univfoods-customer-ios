-- 🏗️ MASTER SYSTEM FLOW ENGINE (Customer + Delivery)
-- Implements strict state transitions, OTP security, payment states, and earnings logic.

BEGIN;

-- 1. EXTEND ORDERS TABLE FOR FULL FLOW
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS payment_state text DEFAULT 'PENDING',
ADD COLUMN IF NOT EXISTS pickup_otp text,
ADD COLUMN IF NOT EXISTS delivery_otp text,
ADD COLUMN IF NOT EXISTS sub_total double precision DEFAULT 0,
ADD COLUMN IF NOT EXISTS delivery_fee double precision DEFAULT 0,
ADD COLUMN IF NOT EXISTS tax_amount double precision DEFAULT 0,
ADD COLUMN IF NOT EXISTS discount_amount double precision DEFAULT 0,
ADD COLUMN IF NOT EXISTS final_amount double precision DEFAULT 0,
ADD COLUMN IF NOT EXISTS is_settled boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS customer_lat double precision,
ADD COLUMN IF NOT EXISTS customer_lng double precision,
ADD COLUMN IF NOT EXISTS vendor_lat double precision,
ADD COLUMN IF NOT EXISTS vendor_lng double precision;

-- 2. EXTEND RIDERS TABLE
ALTER TABLE public.delivery_riders
ADD COLUMN IF NOT EXISTS is_approved boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS is_online boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS active_order_id uuid,
ADD COLUMN IF NOT EXISTS wallet_balance double precision DEFAULT 0;

-- 3. ENSURE VENDORS HAVE RADIUS & STATUS
ALTER TABLE public.vendors
ADD COLUMN IF NOT EXISTS delivery_radius_km double precision DEFAULT 5.0,
ADD COLUMN IF NOT EXISTS min_order_value double precision DEFAULT 100.0;

-- 4. RPC: GENERATE & PLACE ORDER (With OTPs)
CREATE OR REPLACE FUNCTION public.place_customer_order_v1(
    p_customer_id text,
    p_vendor_id uuid,
    p_items jsonb,
    p_total double precision,
    p_address text,
    p_lat double precision,
    p_lng double precision,
    p_payment_method text DEFAULT 'COD'
)
RETURNS uuid AS $$
DECLARE
    v_order_id uuid;
    v_pickup_otp text;
    v_delivery_otp text;
    v_payment_state text;
BEGIN
    -- Validation: Vendor Online? (Simplified check)
    IF NOT EXISTS (SELECT 1 FROM public.vendors WHERE id = p_vendor_id AND status = 'ONLINE') THEN
        RAISE EXCEPTION 'Vendor is currently offline.';
    END IF;

    -- Generate OTPs
    v_pickup_otp := floor(random() * 9000 + 1000)::text;
    v_delivery_otp := floor(random() * 9000 + 1000)::text;
    
    v_payment_state := CASE WHEN p_payment_method = 'COD' THEN 'COD_PENDING' ELSE 'PAID' END;

    INSERT INTO public.orders (
        customer_id, vendor_id, items, total, address, 
        customer_lat, customer_lng, vendor_lat, vendor_lng,
        status, payment_method, 
        payment_state, pickup_otp, delivery_otp, final_amount
    )
    SELECT 
        p_customer_id, p_vendor_id, p_items, p_total, p_address, 
        p_lat, p_lng, v.lat, v.lng,
        'PLACED', p_payment_method, 
        v_payment_state, v_pickup_otp, v_delivery_otp, p_total
    FROM public.vendors v WHERE v.id = p_vendor_id
    RETURNING id INTO v_order_id;

    RETURN v_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. RPC: VERIFY PICKUP OTP
CREATE OR REPLACE FUNCTION public.verify_pickup_otp_v1(
    p_order_id uuid,
    p_otp text
)
RETURNS boolean AS $$
DECLARE
    v_correct_otp text;
BEGIN
    SELECT pickup_otp INTO v_correct_otp FROM public.orders WHERE id = p_order_id;
    
    IF v_correct_otp = p_otp THEN
        UPDATE public.orders 
        SET status = 'PICKED_UP', 
            last_gps_update = now() 
        WHERE id = p_order_id;
        RETURN true;
    ELSE
        RETURN false;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. RPC: UPDATE RIDER LOCATION (Realtime Tracking)
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
    v_c_lat double precision;
    v_c_lng double precision;
    v_dist double precision;
    v_eta integer;
BEGIN
    -- Check if order status is trackable
    SELECT status, customer_lat, customer_lng 
    INTO v_status, v_c_lat, v_c_lng 
    FROM public.orders WHERE id::text = p_order_id;
    
    -- ONLY update if order is in a trackable state (including moving to pickup)
    IF v_status IN ('accepted', 'picking_up', 'picked_up', 'on_the_way', 'ACCEPTED', 'PICKING_UP', 'PICKED_UP', 'ON_THE_WAY') THEN
        
        -- AUTO-CALCULATE Distance/ETA if not provided by client
        IF p_dist_rem = 0 AND v_c_lat IS NOT NULL THEN
             v_dist := (6371 * acos(cos(radians(p_lat)) * cos(radians(v_c_lat)) * cos(radians(v_c_lng) - radians(p_lng)) + sin(radians(p_lat)) * sin(radians(v_c_lat))));
             v_eta := ceil((v_dist / 30.0) * 60); -- Assumes 30km/h avg speed
        ELSE
            v_dist := p_dist_rem;
            v_eta := p_eta_min;
        END IF;

        -- A. Update the Order record (Realtime event for Customer/Admin)
        UPDATE public.orders
        SET 
            -- We keep current_lat/lng as rider position for tracking
            -- Note: in some apps current_lat/lng is used for customer. 
            -- In our schema, orders table current_lat/lng is for RIDER when status is picked_up.
            -- Wait, let's use rider_lat/lng instead to avoid confusion? 
            -- The existing schema uses current_lat/lng for the active participant.
            -- I'll stick to current_lat/lng as assigned in previous turns.
            current_lat = p_lat,
            current_lng = p_lng,
            speed = p_speed,
            heading = p_heading,
            distance_remaining_km = v_dist,
            eta_minutes = v_eta,
            last_gps_update = now()
        WHERE id::text = p_order_id;

        -- B. Update Rider's Global Position
        UPDATE public.delivery_riders
        SET 
            current_lat = p_lat,
            current_lng = p_lng,
            last_gps_update = now()
        WHERE id::text = p_rider_id;

        -- C. Log to tracking history
        INSERT INTO public.order_tracking (order_id, rider_id, latitude, longitude, speed, heading)
        VALUES (p_order_id::uuid, p_rider_id::uuid, p_lat, p_lng, p_speed, p_heading);

    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. RPC: VERIFY DELIVERY OTP & SETTLE
CREATE OR REPLACE FUNCTION public.verify_delivery_otp_v1(
    p_order_id uuid,
    p_otp text
)
RETURNS boolean AS $$
DECLARE
    v_correct_otp text;
    v_rider_id uuid;
    v_total double precision;
    v_payment_method text;
BEGIN
    SELECT delivery_otp, rider_id, total, payment_method 
    INTO v_correct_otp, v_rider_id, v_total, v_payment_method 
    FROM public.orders WHERE id = p_order_id;
    
    IF v_correct_otp = p_otp THEN
        -- 1. Update Order Status
        UPDATE public.orders 
        SET status = 'DELIVERED', 
            payment_state = CASE WHEN v_payment_method = 'COD' THEN 'COD_COLLECTED' ELSE payment_state END,
            is_settled = true
        WHERE id = p_order_id;

        -- 2. Release Rider
        UPDATE public.delivery_riders 
        SET active_order_id = NULL 
        WHERE id = v_rider_id;

        -- 3. Update Rider Wallet (Simplified: 10% commission + 40 fixed)
        UPDATE public.delivery_riders 
        SET wallet_balance = wallet_balance + 40 + (v_total * 0.05)
        WHERE id = v_rider_id;

        RETURN true;
    ELSE
        RETURN false;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. RPC: CANCEL ORDER (Customer)
CREATE OR REPLACE FUNCTION public.cancel_order_customer_v1(
    p_order_id uuid,
    p_user_id text
)
RETURNS boolean AS $$
DECLARE
    v_status text;
BEGIN
    SELECT status INTO v_status FROM public.orders WHERE id = p_order_id AND customer_id = p_user_id;
    
    -- RULE: Only cancel if PLACED/PENDING
    IF v_status IN ('PLACED', 'placed', 'PENDING', 'pending') THEN
        UPDATE public.orders SET status = 'CANCELLED' WHERE id = p_order_id;
        RETURN true;
    ELSE
        RETURN false;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. RPC: GET NEARBY VENDORS (PostGIS logic if available, or simple distance)
CREATE OR REPLACE FUNCTION public.get_nearby_vendors_v2(
    p_lat double precision,
    p_lng double precision
)
RETURNS TABLE (
    id uuid,
    name text,
    address text,
    rating double precision,
    distance_km double precision,
    banner_url text,
    status text
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        v.id, v.name, v.address, v.rating,
        (6371 * acos(cos(radians(p_lat)) * cos(radians(v.lat)) * cos(radians(v.lng) - radians(p_lng)) + sin(radians(p_lat)) * sin(radians(v.lat)))) AS distance_km,
        v.banner_url, v.status
    FROM public.vendors v
    WHERE v.status = 'ONLINE'
      AND (6371 * acos(cos(radians(p_lat)) * cos(radians(v.lat)) * cos(radians(v.lng) - radians(p_lng)) + sin(radians(p_lat)) * sin(radians(v.lat)))) <= v.delivery_radius_km
    -- 10. RPC: FIND & ASSIGN RIDER (Auto Dispatch)
CREATE OR REPLACE FUNCTION public.find_and_assign_rider_v1(
    p_order_id uuid
)
RETURNS boolean AS $$
DECLARE
    v_vendor_lat double precision;
    v_vendor_lng double precision;
    v_rider_id text;
BEGIN
    -- 1. Get vendor location
    SELECT v.lat, v.lng INTO v_vendor_lat, v_vendor_lng
    FROM public.orders o
    JOIN public.vendors v ON o.vendor_id = v.id
    WHERE o.id = p_order_id;

    -- 2. Find nearest online & free rider (within 10km)
    SELECT id INTO v_rider_id
    FROM public.delivery_riders
    WHERE is_online = true 
      AND active_order_id IS NULL
      AND (6371 * acos(cos(radians(v_vendor_lat)) * cos(radians(current_lat)) * cos(radians(current_lng) - radians(v_vendor_lng)) + sin(radians(v_vendor_lat)) * sin(radians(current_lat)))) <= 10
    ORDER BY (6371 * acos(cos(radians(v_vendor_lat)) * cos(radians(current_lat)) * cos(radians(current_lng) - radians(v_vendor_lng)) + sin(radians(v_vendor_lat)) * sin(radians(current_lat))))
    LIMIT 1;

    -- 3. Assign if found
    IF v_rider_id IS NOT NULL THEN
        UPDATE public.orders 
        SET rider_id = v_rider_id::uuid, 
            status = 'RIDER_ASSIGNED',
            meta_data = meta_data || jsonb_build_object('assigned_at', now())
        WHERE id = p_order_id;

        UPDATE public.delivery_riders 
        SET active_order_id = p_order_id 
        WHERE id = v_rider_id;

        RETURN true;
    END IF;

    RETURN false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.find_and_assign_rider_v1 TO authenticated, service_role;

-- 9. PERMISSIONS
GRANT EXECUTE ON FUNCTION public.place_customer_order_v1 TO authenticated;
GRANT EXECUTE ON FUNCTION public.verify_pickup_otp_v1 TO authenticated;
GRANT EXECUTE ON FUNCTION public.verify_delivery_otp_v1 TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_order_customer_v1 TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_nearby_vendors_v2 TO authenticated;

GRANT ALL ON TABLE public.delivery_riders TO authenticated, service_role;
GRANT ALL ON TABLE public.orders TO authenticated, service_role;

COMMIT;

NOTIFY pgrst, 'reload schema';
