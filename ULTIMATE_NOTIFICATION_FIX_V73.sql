-- 🔔 ULTIMATE NOTIFICATION FIX v74.0 (RLS COMPATIBLE)
-- 🎯 Goal: Fix NULL user_id, handle Text vs UUID mismatch, and unify all apps.
-- 🛠️ Instructions: RUN THIS ENTIRE SCRIPT IN YOUR SUPABASE SQL EDITOR.

BEGIN;

-- 1. FIX TABLE SCHEMA (CONVERT TO TEXT FOR FIREBASE UID COMPATIBILITY)
-- ⚠️ DROP POLICIES FIRST (They prevent column type changes)
DROP POLICY IF EXISTS "Users can see their own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Allow all access" ON public.notifications;

-- Some apps use Firebase UIDs (strings), others use UUIDs. TEXT handles both.
ALTER TABLE public.notifications ALTER COLUMN user_id TYPE TEXT;
ALTER TABLE public.notifications ALTER COLUMN order_id TYPE TEXT;

-- RECREATE POLICY (Ensure users can see their own notifications with TEXT ID support)
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can see their own notifications" 
ON public.notifications FOR SELECT 
USING (auth.uid()::TEXT = user_id);


-- 2. ENSURE ALL COMPATIBILITY COLUMNS EXIST
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS body TEXT;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS message TEXT;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS role TEXT;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS user_role TEXT;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS event_type TEXT;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS type TEXT;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS is_read BOOLEAN DEFAULT FALSE;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS read_status BOOLEAN DEFAULT FALSE;

-- 3. SYNC EXISTING DATA (BACKFILL)
UPDATE public.notifications SET message = COALESCE(message, body) WHERE message IS NULL;
UPDATE public.notifications SET body = COALESCE(body, message) WHERE body IS NULL;
UPDATE public.notifications SET user_role = COALESCE(user_role, LOWER(role)) WHERE user_role IS NULL;
UPDATE public.notifications SET role = COALESCE(role, UPPER(user_role)) WHERE role IS NULL;
UPDATE public.notifications SET is_read = COALESCE(is_read, read_status) WHERE is_read IS NULL;
UPDATE public.notifications SET read_status = COALESCE(read_status, is_read) WHERE read_status IS NULL;

-- 4. MASTER UNIFIED TRIGGER FUNCTION
CREATE OR REPLACE FUNCTION public.fn_unified_notification_v73()
RETURNS TRIGGER AS $$
DECLARE
    v_cust_id TEXT;
    v_vend_id TEXT;
    v_rid_id TEXT;
    v_order_id TEXT := NEW.id::TEXT;
    v_short_id TEXT := LEFT(v_order_id, 8);
    v_status TEXT := COALESCE(NEW.order_status, NEW.status, 'PENDING');
    v_total TEXT := COALESCE(NEW.total_amount::TEXT, NEW.total::TEXT, '0');
    v_shop_name TEXT;
BEGIN
    -- Resolve IDs (Handle different column naming conventions across versions)
    v_cust_id := NEW.customer_id::TEXT;
    v_vend_id := NEW.vendor_id::TEXT;
    v_rid_id := COALESCE(NEW.rider_id, NEW.delivery_partner_id, NEW.delivery_id)::TEXT;

    -- Get Shop Name
    SELECT name INTO v_shop_name FROM public.vendors WHERE id::TEXT = v_vend_id LIMIT 1;
    v_shop_name := COALESCE(v_shop_name, 'The Restaurant');

    -- ACTION: ON INSERT (New Order)
    IF (TG_OP = 'INSERT') THEN
        -- Notify Customer
        INSERT INTO public.notifications (user_id, user_role, role, title, message, body, type, event_type, order_id)
        VALUES (v_cust_id, 'customer', 'CUSTOMER', '🍛 Order Placed!', 'Order #' || v_short_id || ' received. Total: ₹' || v_total, 'Order #' || v_short_id || ' received. Total: ₹' || v_total, 'order', 'ORDER_PLACED', v_order_id);
        
        -- Notify Vendor
        INSERT INTO public.notifications (user_id, user_role, role, title, message, body, type, event_type, order_id)
        VALUES (v_vend_id, 'vendor', 'VENDOR', '🚀 New Order!', 'New order #' || v_short_id || ' (₹' || v_total || ') from customer.', 'New order #' || v_short_id || ' (₹' || v_total || ') from customer.', 'order', 'NEW_ORDER', v_order_id);
    END IF;

    -- ACTION: ON UPDATE (Status Change)
    IF (TG_OP = 'UPDATE' AND (NEW.order_status IS DISTINCT FROM OLD.order_status OR NEW.status IS DISTINCT FROM OLD.status)) THEN
        
        -- ACCEPTED / CONFIRMED
        IF (v_status IN ('ACCEPTED', 'CONFIRMED')) THEN
            INSERT INTO public.notifications (user_id, user_role, role, title, message, body, type, event_type, order_id)
            VALUES (v_cust_id, 'customer', 'CUSTOMER', '✅ Order Accepted', v_shop_name || ' is preparing your food.', v_shop_name || ' is preparing your food.', 'order', 'ORDER_ACCEPTED', v_order_id);
        END IF;

        -- RIDER ASSIGNED
        IF (v_status = 'RIDER_ASSIGNED' OR (NEW.rider_id IS NOT NULL AND OLD.rider_id IS NULL)) THEN
            INSERT INTO public.notifications (user_id, user_role, role, title, message, body, type, event_type, order_id)
            VALUES (v_cust_id, 'customer', 'CUSTOMER', '🛵 Rider Assigned', 'A delivery partner is on the way to the restaurant.', 'A delivery partner is on the way to the restaurant.', 'order', 'RIDER_ASSIGNED', v_order_id);
            
            IF v_rid_id IS NOT NULL THEN
                INSERT INTO public.notifications (user_id, user_role, role, title, message, body, type, event_type, order_id)
                VALUES (v_rid_id, 'delivery', 'RIDER', '🛎️ New Task', 'Pickup from ' || v_shop_name || ' for Order #' || v_short_id, 'Pickup from ' || v_shop_name || ' for Order #' || v_short_id, 'order', 'TASK_ASSIGNED', v_order_id);
            END IF;
        END IF;

        -- PICKED_UP / TRANSIT
        IF (v_status IN ('PICKED_UP', 'TRANSIT', 'ON_THE_WAY')) THEN
            INSERT INTO public.notifications (user_id, user_role, role, title, message, body, type, event_type, order_id)
            VALUES (v_cust_id, 'customer', 'CUSTOMER', '🚀 Out for Delivery', 'Your food has been picked up and is on the way!', 'Your food has been picked up and is on the way!', 'order', 'PICKED_UP', v_order_id);
        END IF;

        -- DELIVERED
        IF (v_status = 'DELIVERED') THEN
            INSERT INTO public.notifications (user_id, user_role, role, title, message, body, type, event_type, order_id)
            VALUES (v_cust_id, 'customer', 'CUSTOMER', '🎉 Enjoy your meal!', 'Order delivered successfully. Rate us!', 'Order delivered successfully. Rate us!', 'order', 'DELIVERED', v_order_id);
            
            IF v_rid_id IS NOT NULL THEN
                INSERT INTO public.notifications (user_id, user_role, role, title, message, body, type, event_type, order_id)
                VALUES (v_rid_id, 'delivery', 'RIDER', '✅ Completed', 'Goal achieved! Order #' || v_short_id || ' delivered.', 'Goal achieved! Order #' || v_short_id || ' delivered.', 'order', 'DELIVERY_DONE', v_order_id);
            END IF;
        END IF;

        -- CANCELLED
        IF (v_status = 'CANCELLED') THEN
            INSERT INTO public.notifications (user_id, user_role, role, title, message, body, type, event_type, order_id)
            VALUES (v_cust_id, 'customer', 'CUSTOMER', '❌ Order Cancelled', 'Your order #' || v_short_id || ' was cancelled.', 'Your order #' || v_short_id || ' was cancelled.', 'order', 'ORDER_CANCELLED', v_order_id);
        END IF;

    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. ATTACH UNIFIED TRIGGER
DROP TRIGGER IF EXISTS tr_unified_notifications_v73 ON public.orders;
CREATE TRIGGER tr_unified_notifications_v73
AFTER INSERT OR UPDATE ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.fn_unified_notification_v73();

-- 6. CLEAN UP OLD OBSOLETE TRIGGERS (PREVENT DUPLICATES)
DROP TRIGGER IF EXISTS tr_ultimate_notifications ON public.orders;
DROP TRIGGER IF EXISTS tr_order_notifications ON public.orders;
DROP TRIGGER IF EXISTS on_order_placed ON public.orders;
DROP TRIGGER IF EXISTS on_order_status_changed ON public.orders;
DROP TRIGGER IF EXISTS on_rider_assigned ON public.orders;
DROP TRIGGER IF EXISTS on_payment_status_changed ON public.orders;

-- 7. ROBUST MARK AS READ RPC
CREATE OR REPLACE FUNCTION public.mark_notif_read_v73(p_notif_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE public.notifications 
    SET is_read = TRUE, read_status = TRUE 
    WHERE id = p_notif_id 
    AND (user_id::TEXT = auth.uid()::TEXT);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. REFRESH REALTIME PUBLICATION
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
    END IF;
EXCEPTION WHEN OTHERS THEN 
    RAISE NOTICE 'Notification table already in publication or error: %', SQLERRM;
END $$;

COMMIT;

SELECT '✅ NOTIFICATION ENGINE v74.0 INSTALLED SUCCESSFULLY!' as status;
