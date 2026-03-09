-- =============================================================================
-- 🚨 MASTER STATUS SYNC V80.2 - COMPLETE FIX (All Pre-flight Repairs)
-- =============================================================================
-- Fixes in order:
-- STEP 0: Fix process_order_earnings_v1() - wallets has no user_role column
-- STEP 1: Fix auto_credit_on_delivery()   - COALESCE UUID vs TEXT type mismatch  
-- STEP 2: Sync stale order_status columns
-- STEP 3: Fix update_order_status_v3 RPC to update BOTH columns
-- STEP 4: Add auto-sync trigger (BEFORE UPDATE)
-- STEP 5: Fix notification trigger (uses real customer_id)
-- =============================================================================

BEGIN;

-- ============================================================
-- STEP 0: Fix process_order_earnings_v1()
-- ERROR: column "user_role" of relation "wallets" does not exist
-- Wallet schema: user_id, balance, updated_at, pending_settlement, 
--                lifetime_earnings, cod_debt  (NO user_role!)
-- ============================================================
CREATE OR REPLACE FUNCTION public.process_order_earnings_v1()
RETURNS TRIGGER AS $$
DECLARE
    v_rider_uid   TEXT;
    v_vendor_uid  TEXT;
    v_total       NUMERIC;
    v_platform_cut NUMERIC;
    v_rider_cut    NUMERIC;
    v_vendor_cut   NUMERIC;
BEGIN
    -- Only fire on DELIVERED status change
    IF (TG_OP = 'UPDATE' AND UPPER(NEW.status) = 'DELIVERED' AND 
        UPPER(COALESCE(OLD.status, '')) != 'DELIVERED') THEN

        -- Cast all ID fields to TEXT safely
        v_rider_uid  := COALESCE(NEW.rider_id::TEXT, NEW.delivery_id::TEXT, NEW.delivery_partner_id::TEXT);
        v_vendor_uid := NEW.vendor_id::TEXT;
        v_total      := COALESCE(NEW.total_amount, NEW.total, 0)::NUMERIC;

        -- Earnings split: vendor 70%, rider 10%, platform 20%
        v_platform_cut := ROUND(v_total * 0.20, 2);
        v_rider_cut    := ROUND(v_total * 0.10, 2);
        v_vendor_cut   := ROUND(v_total - v_platform_cut - v_rider_cut, 2);

        -- Credit Rider (no user_role column)
        IF v_rider_uid IS NOT NULL AND v_rider_uid != '' THEN
            INSERT INTO public.wallets (user_id, balance, lifetime_earnings)
            VALUES (v_rider_uid, v_rider_cut, v_rider_cut)
            ON CONFLICT (user_id) DO UPDATE 
            SET balance           = public.wallets.balance + EXCLUDED.balance,
                lifetime_earnings = public.wallets.lifetime_earnings + EXCLUDED.lifetime_earnings,
                updated_at        = NOW();
        END IF;

        -- Credit Vendor (no user_role column)
        IF v_vendor_uid IS NOT NULL AND v_vendor_uid != '' THEN
            INSERT INTO public.wallets (user_id, balance, lifetime_earnings)
            VALUES (v_vendor_uid, v_vendor_cut, v_vendor_cut)
            ON CONFLICT (user_id) DO UPDATE 
            SET balance           = public.wallets.balance + EXCLUDED.balance,
                lifetime_earnings = public.wallets.lifetime_earnings + EXCLUDED.lifetime_earnings,
                updated_at        = NOW();
        END IF;

    END IF;

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    -- NEVER block the order update even if earnings processing fails
    RAISE WARNING 'process_order_earnings_v1 failed: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- STEP 1: Fix auto_credit_on_delivery()
-- ERROR: COALESCE types text and uuid cannot be matched
-- ============================================================
CREATE OR REPLACE FUNCTION public.auto_credit_on_delivery()
RETURNS TRIGGER AS $$
DECLARE
    v_rider_uid  TEXT;
    v_vendor_uid TEXT;
    v_total      NUMERIC;
    v_platform_cut NUMERIC;
    v_rider_cut    NUMERIC;
    v_vendor_cut   NUMERIC;
BEGIN
    IF (TG_OP = 'UPDATE' AND UPPER(NEW.status) = 'DELIVERED' AND 
        UPPER(COALESCE(OLD.status, '')) != 'DELIVERED') THEN

        -- 🔑 Cast ALL to TEXT before COALESCE — fixes UUID vs TEXT error
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
            SET balance           = public.wallets.balance + EXCLUDED.balance,
                lifetime_earnings = public.wallets.lifetime_earnings + EXCLUDED.lifetime_earnings,
                updated_at        = NOW();
        END IF;

        IF v_vendor_uid IS NOT NULL AND v_vendor_uid != '' THEN
            INSERT INTO public.wallets (user_id, balance, lifetime_earnings)
            VALUES (v_vendor_uid, v_vendor_cut, v_vendor_cut)
            ON CONFLICT (user_id) DO UPDATE 
            SET balance           = public.wallets.balance + EXCLUDED.balance,
                lifetime_earnings = public.wallets.lifetime_earnings + EXCLUDED.lifetime_earnings,
                updated_at        = NOW();
        END IF;

    END IF;

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'auto_credit_on_delivery failed: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- STEP 2: Sync all stale order_status → match real status
-- (Safe now because both trigger functions have EXCEPTION blocks)
-- ============================================================
UPDATE public.orders 
SET order_status = status
WHERE order_status IS DISTINCT FROM status;

-- ============================================================
-- STEP 3: Fix update_order_status_v3 RPC to sync BOTH columns
-- ============================================================
CREATE OR REPLACE FUNCTION public.update_order_status_v3(
    p_order_id TEXT,
    p_new_status TEXT
)
RETURNS VOID AS $$
BEGIN
    UPDATE public.orders 
    SET 
        status       = UPPER(p_new_status),
        order_status = UPPER(p_new_status),
        updated_at   = NOW()
    WHERE id::TEXT = p_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- STEP 4: Auto-sync trigger — keeps status and order_status
--         permanently in sync going forward
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
-- STEP 5: Fix notification trigger - uses real customer_id
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
            WHEN 'READY_FOR_PICKUP' THEN
                INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                VALUES (v_customer_id, 'customer', '✅ Food Ready!', 
                    'Your order is ready for pickup!', NEW.id, 'order');
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
-- VERIFY EVERYTHING WORKED
-- ============================================================
DO $$
DECLARE v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count 
    FROM public.orders 
    WHERE UPPER(status) IS DISTINCT FROM UPPER(order_status);
    
    IF v_count > 0 THEN
        RAISE WARNING '⚠️  % orders still have mismatched statuses!', v_count;
    ELSE
        RAISE NOTICE '✅ SUCCESS: All % status columns are in sync!', 
            (SELECT COUNT(*) FROM public.orders);
    END IF;
END $$;

COMMIT;
