-- ==========================================================
-- DAY 7: NOTIFICATIONS + FINAL STABILITY HARDENING
-- Goal: Event-driven notifications. Full system indexing.
--       Run this LAST after Days 1-6 are confirmed working.
-- ==========================================================

BEGIN;

-- 1. NOTIFICATIONS TABLE
CREATE TABLE IF NOT EXISTS public.notifications (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    TEXT        NOT NULL,
  title      TEXT        NOT NULL,
  body       TEXT        NOT NULL,
  type       TEXT        DEFAULT 'ORDER_UPDATE', -- ORDER_UPDATE, PAYMENT, PROMO, SYSTEM, REFUND
  order_id   TEXT,
  is_read    BOOLEAN     DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "RLS_Notifications_V1" ON public.notifications;
CREATE POLICY "RLS_Notifications_V1" ON public.notifications
FOR ALL USING (
  user_id = auth.uid()::text OR
  user_id = (current_setting('request.jwt.claims', true)::json->>'sub') OR
  is_admin_strict()
);

ALTER TABLE public.notifications REPLICA IDENTITY FULL;

DO $$
DECLARE v_all BOOLEAN;
BEGIN
  SELECT puballtables INTO v_all FROM pg_publication WHERE pubname = 'supabase_realtime';
  IF v_all IS NOT TRUE THEN
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications; EXCEPTION WHEN duplicate_object THEN NULL; END;
  END IF;
END $$;

-- 2. NOTIFICATION TRIGGER ON ORDER STATUS CHANGE
CREATE OR REPLACE FUNCTION public.notify_order_status_change()
RETURNS TRIGGER AS $$
DECLARE
  v_title TEXT;
  v_body  TEXT;
  v_type  TEXT := 'ORDER_UPDATE';
BEGIN
  -- Skip if status didn't change
  IF OLD.order_status = NEW.order_status THEN RETURN NEW; END IF;

  -- Build message
  CASE NEW.order_status
    WHEN 'PLACED' THEN
      v_title := '🎉 Order Placed!';
      v_body  := 'Your order has been placed and is waiting for vendor confirmation.';
    WHEN 'ACCEPTED' THEN
      v_title := '✅ Order Accepted!';
      v_body  := 'Your order has been accepted. The kitchen is getting ready!';
    WHEN 'PREPARING' THEN
      v_title := '👨‍🍳 Cooking Started';
      v_body  := 'Your food is being freshly prepared.';
    WHEN 'READY_FOR_PICKUP' THEN
      v_title := '📦 Ready for Pickup!';
      v_body  := 'Your order is packed and waiting for the rider.';
    WHEN 'PICKED_UP' THEN
      v_title := '🛵 On the Way!';
      v_body  := 'Your rider has picked up the order. Track live on the map!';
    WHEN 'DELIVERED' THEN
      v_title := '🎊 Delivered!';
      v_body  := 'Enjoy your meal! Rate your experience in the app.';
      v_type  := 'ORDER_UPDATE';
    WHEN 'CANCELLED' THEN
      v_title := '❌ Order Cancelled';
      v_body  := COALESCE('Reason: ' || NEW.cancellation_reason, 'Your order was cancelled.');
    WHEN 'REJECTED' THEN
      v_title := '⚠️ Order Rejected';
      v_body  := COALESCE('Reason: ' || NEW.rejection_reason, 'The vendor could not fulfil your order.');
    ELSE
      RETURN NEW; -- Unknown status — skip notification
  END CASE;

  -- Notify customer
  INSERT INTO public.notifications (user_id, title, body, type, order_id)
  VALUES (NEW.customer_id, v_title, v_body, v_type, NEW.id::text);

  -- Notify vendor when rider is assigned
  IF NEW.order_status = 'PICKED_UP' AND NEW.vendor_id IS NOT NULL THEN
    INSERT INTO public.notifications (user_id, title, body, type, order_id)
    VALUES (
      NEW.vendor_id,
      '🛵 Rider Picked Up Order',
      'The rider has collected the order #' || LEFT(NEW.id::text, 8),
      'ORDER_UPDATE',
      NEW.id::text
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_notify_order_status ON public.orders;
CREATE TRIGGER tr_notify_order_status
AFTER UPDATE ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.notify_order_status_change();

-- 3. NOTIFY ON NEW ORDER (Trigger for Vendors)
CREATE OR REPLACE FUNCTION public.notify_new_order()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.vendor_id IS NOT NULL THEN
    INSERT INTO public.notifications (user_id, title, body, type, order_id)
    VALUES (
      NEW.vendor_id,
      '🔔 New Order Received!',
      'You have a new order #' || LEFT(NEW.id::text, 8) || '. Tap to accept.',
      'ORDER_UPDATE',
      NEW.id::text
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_notify_new_order ON public.orders;
CREATE TRIGGER tr_notify_new_order
AFTER INSERT ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.notify_new_order();

-- 4. FINAL PERFORMANCE INDEXES
CREATE INDEX IF NOT EXISTS idx_orders_customer_id   ON public.orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_vendor_id     ON public.orders(vendor_id);
CREATE INDEX IF NOT EXISTS idx_orders_rider_id      ON public.orders(rider_id);
CREATE INDEX IF NOT EXISTS idx_orders_delivery_id   ON public.orders(delivery_id);
CREATE INDEX IF NOT EXISTS idx_orders_status        ON public.orders(order_status);
CREATE INDEX IF NOT EXISTS idx_orders_created_at    ON public.orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifs_user_unread   ON public.notifications(user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_wallets_user         ON public.wallets(user_id);
CREATE INDEX IF NOT EXISTS idx_tracking_order       ON public.order_live_tracking(order_id);

-- 5. FINAL PERMISSIONS
GRANT ALL ON public.notifications      TO anon, authenticated, service_role;
GRANT ALL ON public.wallets            TO anon, authenticated, service_role;
GRANT ALL ON public.order_live_tracking TO anon, authenticated, service_role;
GRANT SELECT ON public.order_tracking_v1 TO anon, authenticated, service_role;

COMMIT;
NOTIFY pgrst, 'reload schema';
