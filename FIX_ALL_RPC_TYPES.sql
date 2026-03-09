-- ==========================================
-- 🚀 GLOBAL RPC & TYPE ALIGNMENT FIX
-- ==========================================
-- This script fixes the "Returned type text does not match expected type uuid" errors
-- by realigning all RPC functions to use the new TEXT ID format.

BEGIN;

-- 1. DROP FUNCTIONS TO CLEAR SIGNATURES
DROP FUNCTION IF EXISTS public.get_nearby_vendors_v2(double precision, double precision);
DROP FUNCTION IF EXISTS public.create_payment_intent(uuid, numeric, jsonb, jsonb, text);
DROP FUNCTION IF EXISTS public.create_payment_intent(uuid, numeric, jsonb, jsonb, text, text); -- My previous version
DROP FUNCTION IF EXISTS public.verify_and_create_order(uuid, text);
DROP FUNCTION IF EXISTS public.process_refund(uuid, text);
DROP FUNCTION IF EXISTS public.calculate_settlement();

-- 2. RE-CREATE get_nearby_vendors_v2 WITH TEXT ID
CREATE OR REPLACE FUNCTION public.get_nearby_vendors_v2(
    customer_lat DOUBLE PRECISION,
    customer_lng DOUBLE PRECISION
)
RETURNS TABLE (
    id TEXT, -- FIXED: UUID -> TEXT
    name TEXT,
    address TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    delivery_radius_km DOUBLE PRECISION,
    status TEXT,
    distance_km DOUBLE PRECISION,
    rating DOUBLE PRECISION,
    cuisine_type TEXT,
    image_url TEXT,
    banner_url TEXT,
    delivery_time TEXT,
    is_pure_veg BOOLEAN,
    has_offers BOOLEAN,
    is_busy BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        v.id::TEXT, -- Ensure it is TEXT
        v.name,
        v.address,
        v.latitude,
        v.longitude,
        v.delivery_radius_km,
        v.status,
        (
            6371 * acos(
                LEAST(1.0, GREATEST(-1.0, 
                    cos(radians(customer_lat)) * cos(radians(v.latitude)) *
                    cos(radians(v.longitude) - radians(customer_lng)) +
                    sin(radians(customer_lat)) * sin(radians(v.latitude))
                ))
            )
        ) AS distance_km,
        v.rating,
        v.cuisine_type,
        v.image_url,
        v.banner_url,
        v.delivery_time,
        v.is_pure_veg,
        COALESCE(v.has_offers, FALSE),
        COALESCE(v.is_busy, FALSE)
    FROM public.vendors v
    WHERE 
        v.status IN ('ONLINE', 'OPEN', 'ACTIVE')
        AND v.latitude IS NOT NULL 
        AND v.longitude IS NOT NULL
        AND (
            6371 * acos(
                LEAST(1.0, GREATEST(-1.0, 
                    cos(radians(customer_lat)) * cos(radians(v.latitude)) *
                    cos(radians(v.longitude) - radians(customer_lng)) +
                    sin(radians(customer_lat)) * sin(radians(v.latitude))
                ))
            )
        ) <= 30.0 -- 30km Limit
    ORDER BY distance_km ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. RE-CREATE create_payment_intent (Supports Guests/Test IDs)
CREATE OR REPLACE FUNCTION public.create_payment_intent(
    p_vendor_id TEXT, -- FIXED: UUID -> TEXT
    p_amount NUMERIC,
    p_cart JSONB,
    p_address JSONB,
    p_method TEXT,
    p_customer_id TEXT DEFAULT NULL -- Support custom ID
) RETURNS TEXT AS $$ -- FIXED: RETURNS TEXT (ID of intent)
DECLARE
    v_intent_id UUID;
    v_final_customer_id TEXT;
BEGIN
    v_final_customer_id := COALESCE(p_customer_id, auth.uid()::TEXT);

    INSERT INTO public.payment_intents (customer_id, vendor_id, amount, cart_snapshot, delivery_address, payment_method)
    VALUES (v_final_customer_id, p_vendor_id, p_amount, p_cart, p_address, p_method)
    RETURNING id INTO v_intent_id;
    
    RETURN v_intent_id::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. RE-CREATE verify_and_create_order
CREATE OR REPLACE FUNCTION public.verify_and_create_order(p_intent_id TEXT, p_gateway_id TEXT)
RETURNS TEXT AS $$ -- FIXED: RETURNS TEXT
DECLARE
    v_intent RECORD;
    v_order_id TEXT;
    v_pickup_otp TEXT;
    v_delivery_otp TEXT;
BEGIN
    -- 1. Get Intent
    SELECT * INTO v_intent FROM public.payment_intents WHERE id::TEXT = p_intent_id AND (status = 'pending' OR status = 'temp');
    IF NOT FOUND THEN RETURN NULL; END IF;

    -- 2. Update Intent
    UPDATE public.payment_intents SET status = 'succeeded', gateway_txn_id = p_gateway_id WHERE id::TEXT = p_intent_id;

    -- 3. Generate OTPs
    v_pickup_otp := floor(random() * 9000 + 1000)::text;
    v_delivery_otp := floor(random() * 9000 + 1000)::text;

    -- 4. Create actual order record
    INSERT INTO public.orders (
        customer_id, vendor_id, total, status, payment_method, payment_state, 
        items, delivery_lat, delivery_lng, bill_details, pickup_otp, delivery_otp
    )
    VALUES (
        v_intent.customer_id, 
        v_intent.vendor_id, 
        v_intent.amount, 
        'placed', 
        v_intent.payment_method, 
        CASE WHEN v_intent.payment_method = 'online' THEN 'PAID' ELSE 'COD_PENDING' END,
        v_intent.cart_snapshot, 
        (v_intent.delivery_address->>'lat')::double precision,
        (v_intent.delivery_address->>'lng')::double precision,
        v_intent.cart_snapshot,
        v_pickup_otp,
        v_delivery_otp
    )
    RETURNING id INTO v_order_id;

    RETURN v_order_id::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. RE-CREATE process_refund
CREATE OR REPLACE FUNCTION public.process_refund(p_order_id TEXT, p_reason TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    v_order RECORD;
BEGIN
    SELECT * INTO v_order FROM public.orders WHERE id::TEXT = p_order_id;
    
    IF v_order.status NOT IN ('placed', 'accepted') THEN
        RETURN FALSE;
    END IF;

    UPDATE public.orders 
    SET status = 'cancelled', 
        payment_state = 'REFUND_COMPLETED',
        cancellation_reason = p_reason
    WHERE id::TEXT = p_order_id;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. RE-CREATE Settlement Trigger with TEXT Support
CREATE OR REPLACE FUNCTION public.calculate_settlement()
RETURNS TRIGGER AS $$
DECLARE
    v_vendor_share NUMERIC;
    v_rider_share NUMERIC;
    v_total NUMERIC;
BEGIN
    IF NEW.status = 'delivered' AND (OLD.status IS NULL OR OLD.status != 'delivered') THEN
        v_total := NEW.total;
        v_vendor_share := v_total * 0.85;
        v_rider_share := 40.0; 
        
        INSERT INTO public.settlements (
            order_id, vendor_id, rider_id, order_total, 
            vendor_share, rider_share, platform_commission
        )
        VALUES (
            NEW.id, NEW.vendor_id, NEW.rider_id, v_total, 
            v_vendor_share, v_rider_share, (v_total - v_vendor_share - v_rider_share)
        );
        
        -- Update Balances
        IF NEW.vendor_id IS NOT NULL THEN
            UPDATE public.vendors 
            SET wallet_balance = COALESCE(wallet_balance, 0) + v_vendor_share,
                total_earnings = COALESCE(total_earnings, 0) + v_vendor_share 
            WHERE id::TEXT = NEW.vendor_id::TEXT;
        END IF;
        
        IF NEW.rider_id IS NOT NULL THEN
            UPDATE public.delivery_riders 
            SET wallet_balance = COALESCE(wallet_balance, 0) + v_rider_share,
                total_earnings = COALESCE(total_earnings, 0) + v_rider_share 
            WHERE id::TEXT = NEW.rider_id::TEXT;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. RE-CREATE Helper Views
DROP VIEW IF EXISTS public.view_customer_orders CASCADE;
CREATE OR REPLACE VIEW public.view_customer_orders AS
SELECT 
    o.*,
    v.name as vendor_name,
    v.logo_url as vendor_logo,
    v.address as vendor_address,
    v.latitude as pickup_lat, -- Fixed column name mismatch
    v.longitude as pickup_lng, -- Fixed column name mismatch
    dr.name as rider_name,
    dr.phone as rider_phone,
    dr.vehicle_number as rider_vehicle,
    dr.current_lat as rider_lat,
    dr.current_lng as rider_lng
FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id::TEXT = v.id::TEXT
LEFT JOIN public.delivery_riders dr ON o.rider_id::TEXT = dr.id::TEXT;

-- 8. PERMISSIONS & SCHEMA RELOAD
GRANT EXECUTE ON FUNCTION public.get_nearby_vendors_v2 TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.create_payment_intent TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.verify_and_create_order TO anon, authenticated, service_role;
GRANT SELECT ON public.view_customer_orders TO anon, authenticated, service_role;

NOTIFY pgrst, 'reload schema';

COMMIT;
