-- 🚚 DELIVERY SYSTEM MASTER ARCHITECTURE
-- Implements Point-to-Point Rider Logic, OTP Security, and Assignment Engine

-- 1. EXTEND RIDER PROFILE (Point 1, 2)
ALTER TABLE public.delivery_riders
ADD COLUMN IF NOT EXISTS kyc_status TEXT DEFAULT 'KYC_PENDING', -- KYC_PENDING, ACTIVE, SUSPENDED
ADD COLUMN IF NOT EXISTS bank_details JSONB DEFAULT '{}'::jsonb,
ADD COLUMN IF NOT EXISTS is_online BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS active_order_id UUID DEFAULT NULL,
ADD COLUMN IF NOT EXISTS last_online_at TIMESTAMP WITH TIME ZONE;

-- 2. EXTEND ORDERS FOR DELIVERY SECURITY (Point 5, 7)
ALTER TABLE public.orders
ADD COLUMN IF NOT EXISTS pickup_otp TEXT,
ADD COLUMN IF NOT EXISTS delivery_otp TEXT,
ADD COLUMN IF NOT EXISTS rider_id UUID REFERENCES public.delivery_riders(id),
ADD COLUMN IF NOT EXISTS rider_assigned_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS picked_up_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS cod_collected_amount NUMERIC DEFAULT 0;

-- 3. AUTOMATED ASSIGNMENT ENGINE (Point 3)
-- Finds nearest online rider for a 'READY' order
CREATE OR REPLACE FUNCTION find_and_assign_rider(o_id UUID)
RETURNS VOID AS $$
DECLARE
    v_vendor_lat NUMERIC;
    v_vendor_lng NUMERIC;
    v_rider_id UUID;
BEGIN
    -- Get vendor location from order's vendor
    SELECT latitude, longitude INTO v_vendor_lat, v_vendor_lng 
    FROM public.vendors 
    WHERE id = (SELECT vendor_id FROM public.orders WHERE id = o_id);

    -- Find nearest ONLINE rider who is NOT on an active order (Point 3)
    SELECT id INTO v_rider_id
    FROM public.delivery_riders
    WHERE is_online = true 
    AND kyc_status = 'ACTIVE'
    AND active_order_id IS NULL
    ORDER BY ST_Distance(
        location,
        ST_SetSRID(ST_MakePoint(v_vendor_lng, v_vendor_lat), 4326)::geography
    ) ASC
    LIMIT 1;

    -- Send request (or auto-assign if simple)
    -- For now, we auto-assign for the PIN-TO-PIN logic demo
    IF v_rider_id IS NOT NULL THEN
        UPDATE public.orders 
        SET rider_id = v_rider_id, 
            status = 'rider_assigned', 
            rider_assigned_at = NOW(),
            pickup_otp = LPAD(FLOOR(RANDOM() * 10000)::text, 4, '0'),
            delivery_otp = LPAD(FLOOR(RANDOM() * 10000)::text, 4, '0')
        WHERE id = o_id;

        UPDATE public.delivery_riders 
        SET active_order_id = o_id 
        WHERE id = v_rider_id;
        
        -- Notify Rider
        INSERT INTO public.notifications (target_type, user_id, title, body, data)
        VALUES ('riders', v_rider_id, '🚚 New Order Assigned!', 'You have a new delivery request near you.', jsonb_build_object('order_id', o_id, 'type', 'new_assignment'));
    END IF;
END;
$$ LANGUAGE plpgsql;

-- 4. VERIFICATION LOGIC (Point 5, 7)
-- Secure Pickup with OTP
CREATE OR REPLACE FUNCTION verify_pickup_otp(o_id UUID, input_otp TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    correct_otp TEXT;
BEGIN
    SELECT pickup_otp INTO correct_otp FROM public.orders WHERE id = o_id;
    
    IF correct_otp = input_otp THEN
        UPDATE public.orders 
        SET status = 'picked_up', picked_up_at = NOW() 
        WHERE id = o_id;
        RETURN true;
    END IF;
    RETURN false;
END;
$$ LANGUAGE plpgsql;

-- Secure Delivery with OTP
CREATE OR REPLACE FUNCTION verify_delivery_otp(o_id UUID, input_otp TEXT, cod_amount NUMERIC DEFAULT 0)
RETURNS BOOLEAN AS $$
DECLARE
    correct_otp TEXT;
    v_rider_id UUID;
BEGIN
    SELECT delivery_otp, rider_id INTO correct_otp, v_rider_id FROM public.orders WHERE id = o_id;
    
    IF correct_otp = input_otp THEN
        UPDATE public.orders 
        SET status = 'delivered', 
            delivered_at = NOW(),
            cod_collected_amount = cod_amount,
            payment_state = CASE WHEN cod_amount > 0 THEN 'COD_COLLECTED' ELSE payment_state END
        WHERE id = o_id;

        -- Release Rider
        UPDATE public.delivery_riders SET active_order_id = NULL WHERE id = v_rider_id;
        
        RETURN true;
    END IF;
    RETURN false;
END;
$$ LANGUAGE plpgsql;

-- 5. GPS MONITORING & FRAUD (Point 6, 12)
-- Alert if rider goes offline during delivery
CREATE OR REPLACE FUNCTION check_rider_gps_health()
RETURNS TABLE (rider_id UUID, last_seen INTERVAL) AS $$
BEGIN
    RETURN QUERY
    SELECT id, NOW() - last_online_at
    FROM public.delivery_riders
    WHERE active_order_id IS NOT NULL
    AND last_online_at < NOW() - INTERVAL '1 minute';
END;
$$ LANGUAGE plpgsql;

-- 6. REALTIME PERMISSIONS
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime' AND NOT puballtables) THEN
        IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'delivery_riders') THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.delivery_riders;
        END IF;
    END IF;
END $$;
