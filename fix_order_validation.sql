-- Update order placement function with strict validation
CREATE OR REPLACE FUNCTION place_order_stabilized_v1(p_params JSONB)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_order_id UUID;
    v_customer_id UUID;
    v_vendor_id UUID;
    v_lat DOUBLE PRECISION;
    v_lng DOUBLE PRECISION;
    v_total DOUBLE PRECISION;
    v_items JSONB;
    v_method TEXT;
    v_address TEXT;
    v_pincode TEXT;
    v_phone TEXT;
    v_vendor_lat DOUBLE PRECISION;
    v_vendor_lng DOUBLE PRECISION;
    v_distance_km DOUBLE PRECISION;
BEGIN
    -- Extract values
    v_customer_id := (p_params->>'customer_id')::UUID;
    v_vendor_id := (p_params->>'vendor_id')::UUID;
    v_lat := (p_params->>'lat')::DOUBLE PRECISION;
    v_lng := (p_params->>'lng')::DOUBLE PRECISION;
    v_total := (p_params->>'total')::DOUBLE PRECISION;
    v_items := p_params->'items';
    v_method := p_params->>'payment_method';
    v_address := p_params->>'address';
    v_pincode := p_params->>'pincode';
    v_phone := p_params->>'customer_phone';

    -- 🚨 VALIDATION 1: Empty Fields
    IF v_phone IS NULL OR v_phone = '' THEN
        RAISE EXCEPTION 'Phone number is required';
    END IF;
    IF v_pincode IS NULL OR v_pincode = '' THEN
        RAISE EXCEPTION 'Pincode is required';
    END IF;
    IF v_address IS NULL OR v_address = '' THEN
        RAISE EXCEPTION 'Full delivery address is required';
    END IF;
    IF v_lat IS NULL OR v_lng IS NULL THEN
        RAISE EXCEPTION 'GPS coordinates are required';
    END IF;

    -- 🚨 VALIDATION 2: Distance Check (15 KM Radius)
    SELECT latitude, longitude INTO v_vendor_lat, v_vendor_lng FROM vendors WHERE id = v_vendor_id;
    
    IF v_vendor_lat IS NOT NULL AND v_vendor_lng IS NOT NULL THEN
        v_distance_km := (6371 * acos(
            LEAST(1.0, GREATEST(-1.0, 
                cos(radians(v_lat)) * cos(radians(v_vendor_lat)) * 
                cos(radians(v_vendor_lng) - radians(v_lng)) + 
                sin(radians(v_lat)) * sin(radians(v_vendor_lat))
            ))
        ));

        IF v_distance_km > 15.0 THEN
            RAISE EXCEPTION 'OUT_OF_RADIUS: This restaurant is too far (%.2f KM). Max allowed is 15 KM.', v_distance_km;
        END IF;
    END IF;

    -- Create Order
    INSERT INTO orders (
        customer_id,
        vendor_id,
        items,
        total_amount,
        status,
        payment_method,
        payment_status,
        delivery_address,
        delivery_lat,
        delivery_lng,
        delivery_pincode,
        delivery_phone
    ) VALUES (
        v_customer_id,
        v_vendor_id,
        v_items,
        v_total,
        CASE WHEN v_method = 'UPI' THEN 'PAYMENT_PENDING' ELSE 'PENDING' END,
        v_method,
        CASE WHEN v_method = 'UPI' THEN 'UNPAID' ELSE 'UNPAID' END,
        v_address,
        v_lat,
        v_lng,
        v_pincode,
        v_phone
    ) RETURNING id INTO v_order_id;

    RETURN v_order_id;
END;
$$;
