
-- ULTIMATE PRODUCTION PIPELINE V56.0 (FUNCTION DE-DUPLICATION)
-- 🎯 MISSION: Fix "Multiple Choices" (PGRST203) by removing old UUID-based functions.
-- 🛠️ WHY: You have two versions of place_order_v6. Postgres is confused which one to use.

BEGIN;

-- 1. DROP THE OLD UUID-BASED FUNCTION
-- This specific signature is likely the one causing the "Multiple Choices" conflict.
DROP FUNCTION IF EXISTS public.place_order_v6(uuid, uuid, jsonb, numeric, text, double precision, double precision, text, text, uuid);
DROP FUNCTION IF EXISTS public.place_order_v6(uuid, uuid, jsonb, numeric, text, double precision, double precision, text, text, text);
DROP FUNCTION IF EXISTS public.place_order_v6(text, uuid, jsonb, numeric, text, double precision, double precision, text, text, uuid);

-- 2. ENSURE THE TEXT-BASED VERSION IS THE ONLY ONE STANDING
-- We redefine it one last time to be absolute.
CREATE OR REPLACE FUNCTION public.place_order_v6(
    p_customer_id TEXT,
    p_vendor_id UUID,
    p_items JSONB,
    p_total DECIMAL,
    p_address TEXT,
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION,
    p_payment_method TEXT,
    p_instructions TEXT DEFAULT '',
    p_address_id TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_order_id UUID;
    v_initial_status TEXT;
BEGIN
    -- Standard status logic
    v_initial_status := CASE 
        WHEN p_payment_method IN ('UPI', 'CARD') THEN 'PAYMENT_PENDING' 
        ELSE 'PLACED' 
    END;

    INSERT INTO public.orders (
        customer_id, 
        vendor_id, 
        items, 
        total, 
        status, 
        payment_method, 
        payment_status, 
        address, 
        delivery_address,
        delivery_lat, 
        delivery_lng, 
        cooking_instructions, 
        delivery_address_id, 
        created_at
    ) VALUES (
        p_customer_id, 
        p_vendor_id, 
        p_items, 
        p_total, 
        v_initial_status,
        p_payment_method, 
        'PENDING', 
        p_address, 
        p_address,
        p_lat, 
        p_lng, 
        p_instructions, 
        p_address_id, 
        NOW()
    ) RETURNING id INTO v_order_id;

    RETURN v_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. CLEANUP OTHER POTENTIAL DUPLICATES
DROP FUNCTION IF EXISTS public.get_unified_bootstrap_data(uuid, text);

COMMIT;
NOTIFY pgrst, 'reload schema';
