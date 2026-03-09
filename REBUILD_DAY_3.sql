-- ==========================================================
-- DAY 3: PAYMENT WEBHOOK FIX
-- Goal: Frontend cannot mark payment success. Backend only.
-- ==========================================================

BEGIN;

-- 1. PAYMENTS TABLE (Source of Truth for All Transactions)
CREATE TABLE IF NOT EXISTS public.payments (
  id             UUID      PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id       TEXT      NOT NULL,
  transaction_id TEXT      UNIQUE NOT NULL,
  amount         NUMERIC   NOT NULL,
  currency       TEXT      DEFAULT 'INR',
  method         TEXT      NOT NULL,   -- UPI, CARD, COD, WALLET
  status         TEXT      NOT NULL,   -- SUCCESS, FAILED, REFUNDED
  provider_raw   JSONB,                -- Full gateway response for audit
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "RLS_Payments_V1" ON public.payments;
CREATE POLICY "RLS_Payments_V1" ON public.payments
FOR SELECT USING (
  is_admin_strict() OR
  EXISTS (
    SELECT 1 FROM public.orders
    WHERE orders.id::text = payments.order_id::text
    AND (
      orders.customer_id = auth.uid()::text OR
      orders.customer_id = (current_setting('request.jwt.claims', true)::json->>'sub')
    )
  )
);

-- 2. PAYMENT FINALIZATION RPC (Webhook calls this — not frontend)
-- Frontend never touches payment_status directly.
CREATE OR REPLACE FUNCTION public.finalize_payment_v1(
  p_order_id       TEXT,
  p_transaction_id TEXT,
  p_method         TEXT,
  p_amount         NUMERIC,
  p_provider_raw   JSONB DEFAULT '{}'::JSONB
)
RETURNS JSONB AS $$
DECLARE
  v_current_status TEXT;
BEGIN
  SELECT order_status INTO v_current_status
  FROM public.orders WHERE id::text = p_order_id;

  IF v_current_status IS NULL THEN
    RAISE EXCEPTION 'Order not found: %', p_order_id;
  END IF;

  IF v_current_status != 'PAYMENT_PENDING' THEN
    RETURN jsonb_build_object('success', false, 'message', 'Order not in PAYMENT_PENDING state');
  END IF;

  -- Record the transaction
  INSERT INTO public.payments (order_id, transaction_id, amount, method, status, provider_raw)
  VALUES (p_order_id, p_transaction_id, p_amount, p_method, 'SUCCESS', p_provider_raw);

  -- Transition order to PLACED — backend controlled
  UPDATE public.orders SET
    order_status   = 'PLACED',
    payment_status = 'SUCCESS',
    payment_id     = p_transaction_id,
    updated_at     = NOW()
  WHERE id::text = p_order_id;

  RETURN jsonb_build_object('success', true, 'order_id', p_order_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. PREVENT FRONTEND FROM SETTING payment_status DIRECTLY
-- This trigger fires on any direct UPDATE. If it's not the service_role, reject payment_status changes.
CREATE OR REPLACE FUNCTION public.guard_payment_status()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.payment_status != NEW.payment_status THEN
    -- Only service_role (webhooks/backend) can change payment_status
    -- auth.uid() is NULL when called from service_role, so we allow it
    IF auth.uid() IS NOT NULL AND NOT is_admin_strict() THEN
      NEW.payment_status := OLD.payment_status; -- Silently revert
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_guard_payment_status ON public.orders;
CREATE TRIGGER tr_guard_payment_status
BEFORE UPDATE ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.guard_payment_status();

COMMIT;
NOTIFY pgrst, 'reload schema';
