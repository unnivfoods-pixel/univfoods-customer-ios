-- ==========================================================
-- DAY 6: WALLET + EARNINGS SYSTEM
-- Goal: Backend auto-credits vendor and delivery on DELIVERED.
--       No manual wallet editing.
-- ==========================================================

BEGIN;

-- 1. WALLETS TABLE (Universal — works for Customer, Vendor, Rider)
CREATE TABLE IF NOT EXISTS public.wallets (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        TEXT        UNIQUE NOT NULL,
  role           TEXT        DEFAULT 'customer', -- customer, vendor, delivery
  pending_balance  NUMERIC   DEFAULT 0,   -- Earned but in settlement window
  available_balance NUMERIC  DEFAULT 0,   -- Ready to withdraw
  total_earned   NUMERIC     DEFAULT 0,   -- Lifetime total
  created_at     TIMESTAMPTZ DEFAULT NOW(),
  updated_at     TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "RLS_Wallets_V1" ON public.wallets;
CREATE POLICY "RLS_Wallets_V1" ON public.wallets
FOR ALL USING (
  user_id = auth.uid()::text OR
  user_id = (current_setting('request.jwt.claims', true)::json->>'sub') OR
  is_admin_strict()
);

ALTER TABLE public.wallets REPLICA IDENTITY FULL;

-- 2. AUTO-CREDIT ON DELIVERY TRIGGER
-- Fires when order_status changes to DELIVERED.
-- Credits vendor + delivery automatically. No manual action allowed.
CREATE OR REPLACE FUNCTION public.auto_credit_on_delivery()
RETURNS TRIGGER AS $$
DECLARE
  v_order_total    NUMERIC;
  v_commission     NUMERIC;
  v_vendor_cut     NUMERIC;
  v_delivery_fee   NUMERIC;
  v_vendor_uid     TEXT;
  v_rider_uid      TEXT;
BEGIN
  -- Only execute when transitioning TO 'DELIVERED'
  IF (OLD.order_status = NEW.order_status) OR (NEW.order_status != 'DELIVERED') THEN
    RETURN NEW;
  END IF;

  v_order_total  := COALESCE(NEW.total_amount, NEW.total, 0);
  v_commission   := COALESCE(NEW.commission_rate, 15);
  v_delivery_fee := COALESCE(NEW.delivery_fee, 30);
  v_vendor_cut   := v_order_total * (1 - (v_commission / 100.0)) - v_delivery_fee;

  -- Get vendor owner UID
  SELECT owner_id::text INTO v_vendor_uid
  FROM public.vendors WHERE id::text = NEW.vendor_id LIMIT 1;

  -- Get rider UID
  v_rider_uid := COALESCE(NEW.rider_id, NEW.delivery_id);

  -- Credit VENDOR (into pending_balance — settles after window)
  IF v_vendor_uid IS NOT NULL AND v_vendor_cut > 0 THEN
    INSERT INTO public.wallets (user_id, role, pending_balance, total_earned, updated_at)
    VALUES (v_vendor_uid, 'vendor', v_vendor_cut, v_vendor_cut, NOW())
    ON CONFLICT (user_id) DO UPDATE SET
      pending_balance = wallets.pending_balance + EXCLUDED.pending_balance,
      total_earned    = wallets.total_earned    + EXCLUDED.total_earned,
      updated_at      = NOW();
  END IF;

  -- Credit DELIVERY RIDER (into pending_balance)
  IF v_rider_uid IS NOT NULL AND v_delivery_fee > 0 THEN
    INSERT INTO public.wallets (user_id, role, pending_balance, total_earned, updated_at)
    VALUES (v_rider_uid, 'delivery', v_delivery_fee, v_delivery_fee, NOW())
    ON CONFLICT (user_id) DO UPDATE SET
      pending_balance = wallets.pending_balance + EXCLUDED.pending_balance,
      total_earned    = wallets.total_earned    + EXCLUDED.total_earned,
      updated_at      = NOW();
  END IF;

  -- Stamp the order as settled
  NEW.is_settled       := TRUE;
  NEW.vendor_earning   := v_vendor_cut;
  NEW.settlement_status := 'SETTLED';
  NEW.updated_at       := NOW();

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_auto_credit_on_delivery ON public.orders;
CREATE TRIGGER tr_auto_credit_on_delivery
BEFORE UPDATE ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.auto_credit_on_delivery();

-- 3. SETTLEMENT RELEASE RPC (Admin calls this after settlement window)
-- Moves pending_balance → available_balance for a specific user
CREATE OR REPLACE FUNCTION public.release_pending_balance(p_user_id TEXT)
RETURNS JSONB AS $$
DECLARE
  v_pending NUMERIC;
BEGIN
  SELECT pending_balance INTO v_pending FROM public.wallets WHERE user_id = p_user_id;

  IF v_pending IS NULL OR v_pending <= 0 THEN
    RETURN jsonb_build_object('success', false, 'message', 'No pending balance');
  END IF;

  UPDATE public.wallets SET
    available_balance = available_balance + pending_balance,
    pending_balance   = 0,
    updated_at        = NOW()
  WHERE user_id = p_user_id;

  RETURN jsonb_build_object('success', true, 'released', v_pending);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
NOTIFY pgrst, 'reload schema';
