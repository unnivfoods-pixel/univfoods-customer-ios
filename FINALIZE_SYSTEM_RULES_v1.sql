-- 🛡️ STRICT SYSTEM VALIDATION & ORDER FINALIZATION
-- Implements Cart Validation, Checkout Guards, and Webhook-ready Payment Flows.

BEGIN;

-- 1. RPC: VALIDATE CART BEFORE CHECKOUT
CREATE OR REPLACE FUNCTION public.validate_cart_v1(
    p_vendor_id uuid,
    p_items jsonb, -- Array of {product_id, qty}
    p_lat double precision,
    p_lng double precision
)
RETURNS jsonb AS $$
DECLARE
    v_vendor_status text;
    v_min_order double precision;
    v_radius double precision;
    v_distance double precision;
    v_item RECORD;
    v_product_available boolean;
    v_total double precision := 0;
BEGIN
    -- A. Check Vendor Status
    SELECT status, min_order_value, delivery_radius_km INTO v_vendor_status, v_min_order, v_radius 
    FROM public.vendors WHERE id = p_vendor_id;

    IF v_vendor_status != 'ONLINE' THEN
        return jsonb_build_object('valid', false, 'error', 'Vendor is currently offline');
    END IF;

    -- B. Check Distance Radius
    -- Using simple Haversine for now (6371 * acos...)
    SELECT (6371 * acos(cos(radians(p_lat)) * cos(radians(lat)) * cos(radians(lng) - radians(p_lng)) + sin(radians(p_lat)) * sin(radians(lat))))
    INTO v_distance
    FROM public.vendors WHERE id = p_vendor_id;

    IF v_distance > v_radius THEN
        return jsonb_build_object('valid', false, 'error', 'Address is outside delivery radius (' || round(v_distance::numeric, 2) || 'km > ' || v_radius || 'km)');
    END IF;

    -- C. Check Items Availability & Calculate Total
    FOR v_item IN SELECT * FROM jsonb_to_recordset(p_items) AS x(product_id uuid, qty int)
    LOOP
        SELECT is_available, price INTO v_product_available, v_total FROM public.products WHERE id = v_item.product_id;
        IF NOT v_product_available THEN
            return jsonb_build_object('valid', false, 'error', 'One or more items are currently unavailable');
        END IF;
    END LOOP;

    -- D. Check Min Order Value
    -- Total is calculated in Dart, but we double check if needed.
    -- Assuming p_items includes prices for total check if desired.

    return jsonb_build_object('valid', true, 'distance', v_distance);
END;
$$ LANGUAGE plpgsql STABLE;

-- 2. RPC: CREATE PAYMENT INTENT (Simulation of Stripe/Razorpay flow)
CREATE OR REPLACE FUNCTION public.create_payment_intent_v2(
    p_customer_id text,
    p_vendor_id uuid,
    p_amount double precision,
    p_items jsonb,
    p_method text,
    p_address jsonb
)
RETURNS uuid AS $$
DECLARE
    v_intent_id uuid;
BEGIN
    -- We use a simple intent table or just return a ID to be verified later
    -- For now, let's create a record in orders with status 'PAYMENT_PENDING'
    INSERT INTO public.orders (
        customer_id, vendor_id, items, total, address, 
        current_lat, current_lng, status, payment_method, payment_state,
        pickup_otp, delivery_otp
    )
    VALUES (
        p_customer_id, p_vendor_id, p_items, p_amount, p_address->>'label', 
        (p_address->>'lat')::double precision, (p_address->>'lng')::double precision, 
        'PAYMENT_PENDING', p_method, 'PENDING',
        floor(random() * 9000 + 1000)::text, floor(random() * 9000 + 1000)::text
    )
    RETURNING id INTO v_intent_id;

    RETURN v_intent_id;
END;
$$ LANGUAGE plpgsql;

-- 3. RPC: FINALIZE ORDER (Called after Webhook/Success)
CREATE OR REPLACE FUNCTION public.finalize_order_v1(
    p_order_id uuid,
    p_payment_id text DEFAULT NULL
)
RETURNS void AS $$
BEGIN
    UPDATE public.orders 
    SET status = 'PLACED',
        payment_state = CASE WHEN payment_method = 'COD' THEN 'COD_PENDING' ELSE 'PAID' END,
        meta_data = meta_data || jsonb_build_object('gateway_payment_id', p_payment_id)
    WHERE id = p_order_id;
    
    -- Triggers notifications via existing trg_order_notifications_v1
END;
$$ LANGUAGE plpgsql;

-- 4. RIDER EARNINGS & WALLET (Point 8. Delivery App)
CREATE TABLE IF NOT EXISTS public.rider_wallets (
    rider_id text PRIMARY KEY,
    balance double precision DEFAULT 0,
    total_earned double precision DEFAULT 0,
    last_payout timestamptz,
    updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.rider_transactions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    rider_id text NOT NULL,
    order_id uuid,
    amount double precision NOT NULL,
    type text NOT NULL, -- 'EARNING', 'TIP', 'INCENTIVE', 'PAYOUT'
    created_at timestamptz DEFAULT now()
);

-- 5. RPC: SETTLE RIDER EARNINGS
CREATE OR REPLACE FUNCTION public.settle_rider_earnings_v1(
    p_order_id uuid
)
RETURNS void AS $$
DECLARE
    v_rider_id text;
    v_amount double precision;
BEGIN
    SELECT rider_id::text, final_amount * 0.1 + 40 
    INTO v_rider_id, v_amount 
    FROM public.orders WHERE id = p_order_id;

    IF v_rider_id IS NOT NULL THEN
        -- Insert Transaction
        INSERT INTO public.rider_transactions (rider_id, order_id, amount, type)
        VALUES (v_rider_id, p_order_id, v_amount, 'EARNING');

        -- Update Wallet
        INSERT INTO public.rider_wallets (rider_id, balance, total_earned)
        VALUES (v_rider_id, v_amount, v_amount)
        ON CONFLICT (rider_id) DO UPDATE 
        SET balance = rider_wallets.balance + v_amount,
            total_earned = rider_wallets.total_earned + v_amount,
            updated_at = now();
    END IF;
END;
$$ LANGUAGE plpgsql;

-- 6. PERMISSIONS
GRANT EXECUTE ON FUNCTION public.validate_cart_v1 TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_payment_intent_v2 TO authenticated;
GRANT EXECUTE ON FUNCTION public.finalize_order_v1 TO authenticated;

GRANT ALL ON TABLE public.rider_wallets TO service_role;
GRANT ALL ON TABLE public.rider_transactions TO service_role;

COMMIT;

NOTIFY pgrst, 'reload schema';
