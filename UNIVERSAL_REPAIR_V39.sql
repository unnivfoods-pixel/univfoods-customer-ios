-- UNIVERSAL REPAIR v39.1 (ROBUST CHECKOUT & SQL SNAPSHOTS)
-- 🎯 MISSION: Implement Mandatory Address Validation & Snapshots.
-- 1. Full Snapshots (Phone, Pincode, Address, Name).
-- 2. Radius Validation (Max 15km).
-- 3. Required Field Validation.

BEGIN;

CREATE OR REPLACE FUNCTION place_order_stabilized_v1(p_params JSONB)
RETURNS TEXT AS $$
DECLARE
    v_order_id TEXT;
    v_customer_id TEXT;
    v_vendor_id TEXT;
    v_vendor_lat NUMERIC;
    v_vendor_lng NUMERIC;
    v_total NUMERIC;
    v_delivery_lat NUMERIC;
    v_delivery_lng NUMERIC;
    v_delivery_address TEXT;
    v_delivery_phone TEXT;
    v_delivery_pincode TEXT;
    v_customer_name TEXT;
    v_dist_km NUMERIC;
BEGIN
    -- 1. EXTRACT DATA
    v_customer_id := (p_params->>'customer_id');
    IF v_customer_id IS NULL THEN
        v_customer_id := auth.uid()::text;
    END IF;

    v_vendor_id := (p_params->>'vendor_id');
    v_total := (p_params->>'total')::NUMERIC;
    
    v_delivery_lat := (p_params->>'lat')::NUMERIC;
    v_delivery_lng := (p_params->>'lng')::NUMERIC;
    v_delivery_address := (p_params->>'address');
    v_delivery_phone := (p_params->>'customer_phone');
    v_delivery_pincode := (p_params->>'pincode');
    
    -- Try to get name for snapshot
    SELECT full_name INTO v_customer_name FROM customer_profiles WHERE id::text = v_customer_id LIMIT 1;

    -- 2. MANDATORY FIELD VALIDATION
    IF v_delivery_lat IS NULL OR v_delivery_lng IS NULL THEN
        RAISE EXCEPTION 'Latitude and Longitude are required.';
    END IF;

    IF v_delivery_address IS NULL OR v_delivery_address = '' THEN
        RAISE EXCEPTION 'Full delivery address is required.';
    END IF;

    IF v_delivery_phone IS NULL OR v_delivery_phone = '' THEN
        RAISE EXCEPTION 'Contact phone number is required.';
    END IF;

    IF v_delivery_pincode IS NULL OR v_delivery_pincode = '' THEN
        RAISE EXCEPTION 'Pincode is required.';
    END IF;

    -- 3. GET VENDOR COORDS & RADIUS VALIDATION
    SELECT latitude, longitude INTO v_vendor_lat, v_vendor_lng 
    FROM vendors WHERE id::text = v_vendor_id LIMIT 1;

    IF v_vendor_lat IS NOT NULL AND v_vendor_lng IS NOT NULL THEN
        -- Using Haversine is better but simple euclidean for quick check
        v_dist_km := sqrt(pow((v_vendor_lat - v_delivery_lat) * 111, 2) + pow((v_vendor_lng - v_delivery_lng) * 111, 2));
        
        IF v_dist_km > 15 THEN
            RAISE EXCEPTION 'Delivery location is too far (% km). Max limit is 15km.', round(v_dist_km, 1);
        END IF;
    END IF;

    -- 4. INSERT ORDER WITH FULL SNAPSHOT
    -- We populate BOTH legacy and new snapshot columns to be absolutely safe
    INSERT INTO orders (
        customer_id,
        user_id,
        vendor_id,
        delivery_lat,
        delivery_lng,
        delivery_address,
        delivery_phone,
        delivery_pincode,
        -- Snapshots
        delivery_address_snapshot,
        delivery_lat_snapshot,
        delivery_lng_snapshot,
        customer_phone_snapshot,
        customer_name_snapshot,
        -- Statuses
        order_status,
        payment_status,
        total,
        total_amount,
        items,
        vendor_lat,
        vendor_lng,
        created_at
    ) VALUES (
        v_customer_id,
        v_customer_id,
        v_vendor_id,
        v_delivery_lat,
        v_delivery_lng,
        v_delivery_address,
        v_delivery_phone,
        v_delivery_pincode,
        v_delivery_address,
        v_delivery_lat,
        v_delivery_lng,
        v_delivery_phone,
        COALESCE(v_customer_name, 'Guest'),
        CASE WHEN (p_params->>'payment_method') = 'COD' THEN 'PLACED' ELSE 'PAYMENT_PENDING' END,
        CASE WHEN (p_params->>'payment_method') = 'COD' THEN 'COD_PENDING' ELSE 'PENDING' END,
        v_total,
        v_total,
        (p_params->'items'),
        COALESCE(v_vendor_lat, 0),
        COALESCE(v_vendor_lng, 0),
        NOW()
    ) RETURNING id::text INTO v_order_id;

    RETURN v_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
SELECT 'UNIVERSAL REPAIR V39.1 COMPLETE' as status;

