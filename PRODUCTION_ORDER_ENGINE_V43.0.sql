-- 🛰️ PRODUCTION ORDER ENGINE V43.0
-- 🎯 MISSION: Strict Payment & Placement Logic.
-- 🛠️ RULE: No Order is "PLACED" without Payment Confirmation (unless COD).

BEGIN;

-- 1. DROP OLD PLACEMENT FUNCTIONS
DROP FUNCTION IF EXISTS public.place_order_v5(TEXT, UUID, JSONB, DECIMAL, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT, TEXT, TEXT, TEXT);

-- 2. THE PRODUCTION PLACEMENT FUNCTION (v6)
CREATE OR REPLACE FUNCTION public.place_order_v6(
    p_customer_id UUID,
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
    -- Strict initial status logic
    IF p_payment_method = 'UPI' OR p_payment_method = 'CARD' THEN
        v_initial_status := 'PAYMENT_PENDING';
    ELSE
        v_initial_status := 'PLACED';
    END IF;

    -- Insert the master order record
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

    -- Insert notifications for Admin and Vendor
    INSERT INTO public.notifications (user_id, title, message, type)
    VALUES (
        (SELECT owner_id FROM public.vendors WHERE id = p_vendor_id),
        'New Mission Incoming!',
        'You have received a new order. Open terminal to accept.',
        'NEW_ORDER'
    );

    RETURN v_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. PAYMENT WEBHOOK SIMULATOR / HANDLER
-- In production, your webhook will call this:
CREATE OR REPLACE FUNCTION public.confirm_order_payment(p_order_id UUID, p_payment_id TEXT)
RETURNS VOID AS $$
BEGIN
    UPDATE public.orders 
    SET status = 'PLACED', 
        payment_status = 'PAID', 
        payment_id = p_payment_id,
        confirmed_at = NOW()
    WHERE id = p_order_id AND status = 'PAYMENT_PENDING';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
NOTIFY pgrst, 'reload schema';
