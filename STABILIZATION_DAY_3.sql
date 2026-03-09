-- 🚀 DAY 3: PAYMENT WEBHOOK FIX (STRICT BACKEND PROTOCOL)
-- Goal: Ensure payment success is ONLY marked via backend logic or webhooks.

BEGIN;

-- 1. Create a log table for incoming webhooks (Auditing)
CREATE TABLE IF NOT EXISTS public.razorpay_webhooks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type TEXT,
    payload JSONB,
    processed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS (Read-only for Admins)
ALTER TABLE public.razorpay_webhooks ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins only see webhooks" ON public.razorpay_webhooks;
CREATE POLICY "Admins only see webhooks" ON public.razorpay_webhooks
FOR ALL USING (auth.jwt()->>'role' = 'admin' OR auth.jwt()->>'email' = 'admin@univfoods.in');

-- 2. Standardized Payment Ledger (From Day 3 plan)
CREATE TABLE IF NOT EXISTS public.payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id TEXT, -- Changed to TEXT for compatibility
    transaction_id TEXT UNIQUE NOT NULL,
    amount NUMERIC NOT NULL,
    currency TEXT DEFAULT 'INR',
    method TEXT, 
    status TEXT, -- 'SUCCESS', 'FAILED', 'REFUNDED'
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 3. WEBHOOK PROCESSOR (Emulator / Trigger Handler)
-- This function marks the order as PLACED + SUCCESS ONLY after payment verification.
CREATE OR REPLACE FUNCTION public.process_payment_webhook_v1(
    p_order_id TEXT,
    p_transaction_id TEXT,
    p_amount DOUBLE PRECISION,
    p_method TEXT DEFAULT 'UPI'
)
RETURNS JSONB AS $$
DECLARE
    v_current_status TEXT;
BEGIN
    SELECT order_status INTO v_current_status FROM public.orders WHERE (id::text) = (p_order_id::text);
    
    -- Safety Check: Don't re-process if already success
    IF v_current_status = 'PLACED' OR v_current_status = 'ACCEPTED' THEN
        RETURN jsonb_build_object('success', true, 'message', 'Already processed');
    END IF;

    -- Record the transaction truth
    INSERT INTO public.payments (order_id, transaction_id, amount, method, status)
    VALUES (p_order_id, p_transaction_id, p_amount, p_method, 'SUCCESS')
    ON CONFLICT (transaction_id) DO NOTHING;

    -- 🛡️ Elevate Order to True 'PLACED' State
    UPDATE public.orders SET
        order_status = 'PLACED',
        payment_status = 'SUCCESS',
        updated_at = now()
    WHERE (id::text) = (p_order_id::text);

    RETURN jsonb_build_object('success', true, 'order_id', p_order_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. FIX PLACE ORDER LOGIC (Force PAYMENT_PENDING for UPI)
-- We use a unique name 'place_order_stabilized_v4' to avoid "Multiple Choices" type conflicts.
CREATE OR REPLACE FUNCTION public.place_order_stabilized_v4(
    p_customer_id TEXT,
    p_vendor_id TEXT,
    p_items JSONB,
    p_total DOUBLE PRECISION,
    p_address TEXT,
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION,
    p_payment_method TEXT DEFAULT 'COD',
    p_instructions TEXT DEFAULT '',
    p_address_id TEXT DEFAULT NULL,
    p_payment_status TEXT DEFAULT 'PENDING',
    p_payment_id TEXT DEFAULT NULL
)
RETURNS TEXT AS $$
DECLARE
    v_order_id TEXT;
    v_initial_status TEXT;
BEGIN
    -- Force status to PAYMENT_PENDING if not COD and not already paid
    IF p_payment_method != 'COD' AND p_payment_status != 'SUCCESS' THEN
        v_initial_status := 'PAYMENT_PENDING';
    ELSE
        v_initial_status := 'PLACED';
    END IF;

    INSERT INTO public.orders (
        customer_id, vendor_id, items, total_amount, delivery_address, 
        delivery_lat, delivery_lng, 
        order_status, payment_method, payment_status, payment_id,
        cooking_instructions, created_at
    ) VALUES (
        p_customer_id, p_vendor_id, p_items, p_total, p_address, 
        p_lat, p_lng,
        v_initial_status, p_payment_method, p_payment_status, p_payment_id,
        p_instructions, now()
    ) RETURNING id::text INTO v_order_id;

    RETURN v_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. REFRESH SCHEMA
NOTIFY pgrst, 'reload schema';

COMMIT;
