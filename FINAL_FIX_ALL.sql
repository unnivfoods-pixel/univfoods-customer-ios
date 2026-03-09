-- ========================================================================
-- 🚀 FINAL_FIX_ALL.sql  — Run this ONE file in Supabase SQL Editor
--    Combines MASTER_STATUS_SYNC_V80 + NOTIFICATION_REALTIME_FIX_V81
-- ========================================================================

BEGIN;

-- ============================================================
-- PART 1A: Fix process_order_earnings_v1()
-- Bug: wallets table has no 'user_role' column
-- ============================================================
CREATE OR REPLACE FUNCTION public.process_order_earnings_v1()
RETURNS TRIGGER AS $$
DECLARE
    v_rider_uid    TEXT;
    v_vendor_uid   TEXT;
    v_total        NUMERIC;
    v_platform_cut NUMERIC;
    v_rider_cut    NUMERIC;
    v_vendor_cut   NUMERIC;
BEGIN
    IF (TG_OP = 'UPDATE' AND UPPER(NEW.status) = 'DELIVERED' AND
        UPPER(COALESCE(OLD.status, '')) != 'DELIVERED') THEN
        v_rider_uid  := COALESCE(NEW.rider_id::TEXT, NEW.delivery_id::TEXT, NEW.delivery_partner_id::TEXT);
        v_vendor_uid := NEW.vendor_id::TEXT;
        v_total      := COALESCE(NEW.total_amount, NEW.total, 0)::NUMERIC;
        v_platform_cut := ROUND(v_total * 0.20, 2);
        v_rider_cut    := ROUND(v_total * 0.10, 2);
        v_vendor_cut   := ROUND(v_total - v_platform_cut - v_rider_cut, 2);
        IF v_rider_uid IS NOT NULL AND v_rider_uid != '' THEN
            INSERT INTO public.wallets (user_id, balance, lifetime_earnings)
            VALUES (v_rider_uid, v_rider_cut, v_rider_cut)
            ON CONFLICT (user_id) DO UPDATE
            SET balance = public.wallets.balance + EXCLUDED.balance,
                lifetime_earnings = public.wallets.lifetime_earnings + EXCLUDED.lifetime_earnings,
                updated_at = NOW();
        END IF;
        IF v_vendor_uid IS NOT NULL AND v_vendor_uid != '' THEN
            INSERT INTO public.wallets (user_id, balance, lifetime_earnings)
            VALUES (v_vendor_uid, v_vendor_cut, v_vendor_cut)
            ON CONFLICT (user_id) DO UPDATE
            SET balance = public.wallets.balance + EXCLUDED.balance,
                lifetime_earnings = public.wallets.lifetime_earnings + EXCLUDED.lifetime_earnings,
                updated_at = NOW();
        END IF;
    END IF;
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'process_order_earnings_v1 failed: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- PART 1B: Fix auto_credit_on_delivery()
-- Bug: COALESCE(uuid, text) type mismatch
-- ============================================================
CREATE OR REPLACE FUNCTION public.auto_credit_on_delivery()
RETURNS TRIGGER AS $$
DECLARE
    v_rider_uid    TEXT;
    v_vendor_uid   TEXT;
    v_total        NUMERIC;
    v_platform_cut NUMERIC;
    v_rider_cut    NUMERIC;
    v_vendor_cut   NUMERIC;
BEGIN
    IF (TG_OP = 'UPDATE' AND UPPER(NEW.status) = 'DELIVERED' AND
        UPPER(COALESCE(OLD.status, '')) != 'DELIVERED') THEN
        v_rider_uid  := COALESCE(NEW.rider_id::TEXT, NEW.delivery_id::TEXT, NEW.delivery_partner_id::TEXT);
        v_vendor_uid := NEW.vendor_id::TEXT;
        v_total      := COALESCE(NEW.total_amount, NEW.total, 0)::NUMERIC;
        v_platform_cut := ROUND(v_total * 0.20, 2);
        v_rider_cut    := ROUND(v_total * 0.10, 2);
        v_vendor_cut   := ROUND(v_total - v_platform_cut - v_rider_cut, 2);
        IF v_rider_uid IS NOT NULL AND v_rider_uid != '' THEN
            INSERT INTO public.wallets (user_id, balance, lifetime_earnings)
            VALUES (v_rider_uid, v_rider_cut, v_rider_cut)
            ON CONFLICT (user_id) DO UPDATE
            SET balance = public.wallets.balance + EXCLUDED.balance,
                lifetime_earnings = public.wallets.lifetime_earnings + EXCLUDED.lifetime_earnings,
                updated_at = NOW();
        END IF;
        IF v_vendor_uid IS NOT NULL AND v_vendor_uid != '' THEN
            INSERT INTO public.wallets (user_id, balance, lifetime_earnings)
            VALUES (v_vendor_uid, v_vendor_cut, v_vendor_cut)
            ON CONFLICT (user_id) DO UPDATE
            SET balance = public.wallets.balance + EXCLUDED.balance,
                lifetime_earnings = public.wallets.lifetime_earnings + EXCLUDED.lifetime_earnings,
                updated_at = NOW();
        END IF;
    END IF;
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'auto_credit_on_delivery failed: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- PART 2: Sync all stale order_status = status (one-time fix)
-- ============================================================
UPDATE public.orders
SET order_status = status
WHERE order_status IS DISTINCT FROM status;

-- ============================================================
-- PART 3: Fix RPC - update BOTH status columns every time
-- ============================================================
CREATE OR REPLACE FUNCTION public.update_order_status_v3(
    p_order_id TEXT,
    p_new_status TEXT
)
RETURNS VOID AS $$
BEGIN
    UPDATE public.orders
    SET status       = UPPER(p_new_status),
        order_status = UPPER(p_new_status),
        updated_at   = NOW()
    WHERE id::TEXT = p_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- PART 4: Auto-sync trigger (keeps both columns in sync forever)
-- ============================================================
CREATE OR REPLACE FUNCTION public.sync_order_status_columns()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status IS DISTINCT FROM OLD.status THEN
        NEW.order_status := NEW.status;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS sync_status_columns_trigger ON public.orders;
CREATE TRIGGER sync_status_columns_trigger
    BEFORE UPDATE ON public.orders
    FOR EACH ROW EXECUTE FUNCTION sync_order_status_columns();

-- ============================================================
-- PART 5: Fix notification trigger (send to real customer_id)
-- ============================================================
CREATE OR REPLACE FUNCTION handle_core_notifications_v3()
RETURNS TRIGGER AS $$
DECLARE
    v_customer_id    TEXT;
    v_order_short_id TEXT;
BEGIN
    v_order_short_id := SUBSTRING(NEW.id::TEXT, 1, 8);
    v_customer_id    := NEW.customer_id::TEXT;

    IF (TG_OP = 'INSERT') THEN
        INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
        VALUES (v_customer_id, 'customer', '🎉 Order Placed!',
            'Your order #' || v_order_short_id || ' was placed.', NEW.id, 'order')
        ON CONFLICT DO NOTHING;
    END IF;

    IF (TG_OP = 'UPDATE' AND UPPER(NEW.status) != UPPER(COALESCE(OLD.status, ''))) THEN
        CASE UPPER(NEW.status)
            WHEN 'ACCEPTED' THEN
                INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                VALUES (v_customer_id, 'customer', '👨‍🍳 Order Accepted!',
                    'Restaurant is preparing order #' || v_order_short_id, NEW.id, 'order');
            WHEN 'PREPARING' THEN
                INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                VALUES (v_customer_id, 'customer', '🍳 Preparing Your Food',
                    'Your delicious meal is being cooked!', NEW.id, 'order');
            WHEN 'READY' THEN
                INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                VALUES (v_customer_id, 'customer', '✅ Food Ready!',
                    'Your order is ready, rider is picking it up.', NEW.id, 'order');
            WHEN 'PICKED_UP' THEN
                INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                VALUES (v_customer_id, 'customer', '🚴 Out for Delivery!',
                    'Your order is on the way!', NEW.id, 'order');
            WHEN 'ON_THE_WAY' THEN
                INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                VALUES (v_customer_id, 'customer', '🚴 Almost There!',
                    'Rider is almost at your location!', NEW.id, 'order');
            WHEN 'DELIVERED' THEN
                INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                VALUES (v_customer_id, 'customer', '🎉 Delivered!',
                    'Enjoy your meal! Rate your experience ⭐', NEW.id, 'order');
            WHEN 'CANCELLED' THEN
                INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                VALUES (v_customer_id, 'customer', '❌ Order Cancelled',
                    'Your order #' || v_order_short_id || ' was cancelled.', NEW.id, 'order');
            ELSE NULL;
        END CASE;
    END IF;

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Notification trigger failed: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS core_notification_trigger ON public.orders;
CREATE TRIGGER core_notification_trigger
    AFTER INSERT OR UPDATE ON public.orders
    FOR EACH ROW EXECUTE FUNCTION handle_core_notifications_v3();

-- ============================================================
-- PART 6: Enable Realtime for notifications and orders tables
-- ============================================================
ALTER TABLE public.notifications REPLICA IDENTITY FULL;
ALTER TABLE public.orders REPLICA IDENTITY FULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND tablename = 'notifications'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
        RAISE NOTICE 'notifications added to realtime';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND tablename = 'orders'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
        RAISE NOTICE 'orders added to realtime';
    END IF;
END $$;

-- Allow all reads on notifications (app uses custom auth, not Supabase auth)
DROP POLICY IF EXISTS "Allow all notification reads" ON public.notifications;
CREATE POLICY "Allow all notification reads"
    ON public.notifications FOR ALL USING (true);

-- ============================================================
-- VERIFY
-- ============================================================
DO $$
DECLARE v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM public.orders
    WHERE UPPER(status) IS DISTINCT FROM UPPER(order_status);
    IF v_count > 0 THEN
        RAISE WARNING '% orders still mismatched!', v_count;
    ELSE
        RAISE NOTICE '✅ ALL DONE! % orders synced. Notifications enabled.',
            (SELECT COUNT(*) FROM public.orders);
    END IF;
END $$;

COMMIT;
