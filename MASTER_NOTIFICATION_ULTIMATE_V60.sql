-- 🔔 ULTIMATE NOTIFICATION SYSTEM v60.0
-- 📦 ALL 20 SCENARIOS FOR CUSTOMER, VENDOR, AND RIDER
-- Consolidated for Real-time compatibility across all apps.

-- 1. UNIFY NOTIFICATION TABLE
-- Ensure all columns used by DIFFERENT APPS exist
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS message text;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS body text;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS type text;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS event_type text;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS read_status boolean DEFAULT false;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS is_read boolean DEFAULT false;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS order_id text;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS user_id text;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS role text;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS image_url text;

-- Sync columns if one is set but not the other
UPDATE public.notifications SET message = body WHERE message IS NULL AND body IS NOT NULL;
UPDATE public.notifications SET body = message WHERE body IS NULL AND message IS NOT NULL;
UPDATE public.notifications SET is_read = read_status WHERE is_read IS NULL;
UPDATE public.notifications SET read_status = is_read WHERE read_status IS NULL;

-- 2. MASTER NOTIFICATION FUNCTION
CREATE OR REPLACE FUNCTION public.proc_ultimate_notifications()
RETURNS TRIGGER AS $$
DECLARE
    v_order_id text := NEW.id::text;
    v_short_id text := SUBSTRING(NEW.id::text, 1, 8);
    v_cust_id text := NEW.customer_id::text;
    v_vend_id text := NEW.vendor_id::text;
    v_rid_id text := NEW.delivery_id::text; 
    v_rest_name text;
    v_rider_name text;
    v_total text := COALESCE(NEW.total::text, '0');
    v_dist float;
BEGIN
    SELECT name INTO v_rest_name FROM public.vendors WHERE id::text = v_vend_id;
    IF v_rid_id IS NOT NULL THEN
        SELECT name INTO v_rider_name FROM public.delivery_riders WHERE id::text = v_rid_id;
    END IF;

    v_rest_name := COALESCE(v_rest_name, 'Royal Curry House');
    v_rider_name := COALESCE(v_rider_name, 'Our Delivery Partner');

    IF (TG_OP = 'INSERT') THEN
        INSERT INTO public.notifications (user_id, title, message, body, type, event_type, order_id, is_read, read_status, role)
        VALUES (v_cust_id, '🔔 Order Confirmed', 'Your order #' || v_short_id || ' has been placed successfully.', 'Your order #' || v_short_id || ' has been placed successfully.', 'order', 'ORDER_PLACED', v_order_id, false, false, 'CUSTOMER');
        
        INSERT INTO public.notifications (user_id, title, message, body, type, event_type, order_id, is_read, read_status, role)
        VALUES (v_vend_id, '🚀 New Order Received', 'New order #' || v_short_id || ' (₹' || v_total || ') from customer.', 'New order #' || v_short_id || ' (₹' || v_total || ') from customer.', 'order', 'NEW_ORDER', v_order_id, false, false, 'VENDOR');
        
        RETURN NEW;
    END IF;

    IF (NEW.payment_status IS DISTINCT FROM OLD.payment_status AND (LOWER(NEW.payment_status) = 'success' OR LOWER(NEW.payment_status) = 'paid')) THEN
        INSERT INTO public.notifications (user_id, title, message, body, type, event_type, order_id, role)
        VALUES (v_cust_id, '🔔 Payment Successful', '₹' || v_total || ' payment received. Restaurant is preparing your order.', '₹' || v_total || ' payment received. Restaurant is preparing your order.', 'payment', 'PAYMENT_SUCCESS', v_order_id, 'CUSTOMER');
    END IF;

    IF (NEW.payment_status IS DISTINCT FROM OLD.payment_status AND LOWER(NEW.payment_status) = 'failed') THEN
        INSERT INTO public.notifications (user_id, title, message, body, type, event_type, order_id, role)
        VALUES (v_cust_id, '🔴 Payment Failed', 'Your payment failed. Please retry to confirm your order.', 'Your payment failed. Please retry to confirm your order.', 'payment', 'PAYMENT_FAILED', v_order_id, 'CUSTOMER');
    END IF;

    IF (NEW.status IS DISTINCT FROM OLD.status AND (LOWER(NEW.status) = 'accepted' OR LOWER(NEW.status) = 'confirmed')) THEN
        INSERT INTO public.notifications (user_id, title, message, body, type, event_type, order_id, role)
        VALUES (v_cust_id, '🔔 Restaurant Accepted', v_rest_name || ' is preparing your food.', v_rest_name || ' is preparing your food.', 'order', 'ORDER_ACCEPTED', v_order_id, 'CUSTOMER');
    END IF;

    IF (NEW.status IS DISTINCT FROM OLD.status AND LOWER(NEW.status) = 'rejected') THEN
        INSERT INTO public.notifications (user_id, title, message, body, type, event_type, order_id, role)
        VALUES (v_cust_id, '❌ Order Cancelled by Restaurant', 'The restaurant couldn’t process your order. Refund initiated.', 'The restaurant couldn’t process your order. Refund initiated.', 'order', 'ORDER_REJECTED', v_order_id, 'CUSTOMER');
    END IF;

    IF (NEW.status IS DISTINCT FROM OLD.status AND LOWER(NEW.status) = 'preparing') THEN
        INSERT INTO public.notifications (user_id, title, message, body, type, event_type, order_id, role)
        VALUES (v_cust_id, '👨‍🍳 Preparing Food', 'Your food is being cooked fresh at ' || v_rest_name || '.', 'Your food is being cooked fresh at ' || v_rest_name || '.', 'order', 'PREPARING', v_order_id, 'CUSTOMER');
    END IF;

    IF (NEW.status IS DISTINCT FROM OLD.status AND LOWER(NEW.status) = 'ready') THEN
        INSERT INTO public.notifications (user_id, title, message, body, type, event_type, order_id, role)
        VALUES (v_cust_id, '📦 Order Ready', 'The restaurant has packed your food. Your rider is arriving.', 'The restaurant has packed your food. Your rider is arriving.', 'order', 'READY', v_order_id, 'CUSTOMER');
    END IF;

    IF (NEW.delivery_id IS DISTINCT FROM OLD.delivery_id AND NEW.delivery_id IS NOT NULL) THEN
        INSERT INTO public.notifications (user_id, title, message, body, type, event_type, order_id, role)
        VALUES (v_cust_id, '🛵 Rider Assigned', v_rider_name || ' is delivering your order.', v_rider_name || ' is delivering your order.', 'delivery', 'RIDER_ASSIGNED', v_order_id, 'CUSTOMER');
        
        INSERT INTO public.notifications (user_id, title, message, body, type, event_type, order_id, role)
        VALUES (v_rid_id, '🛎️ New Delivery Task', 'Order #' || v_short_id || ' assigned. Navigate to ' || v_rest_name || '.', 'Order #' || v_short_id || ' assigned. Navigate to ' || v_rest_name || '.', 'delivery', 'TASK_ASSIGNED', v_order_id, 'RIDER');
    END IF;

    IF (NEW.status IS DISTINCT FROM OLD.status AND (LOWER(NEW.status) = 'transit' OR LOWER(NEW.status) = 'picked_up')) THEN
        INSERT INTO public.notifications (user_id, title, message, body, type, event_type, order_id, role)
        VALUES (v_cust_id, '📦 Order Picked Up', 'Your order is on the way! Track live now.', 'Your order is on the way! Track live now.', 'order', 'IN_TRANSIT', v_order_id, 'CUSTOMER');
    END IF;

    IF (NEW.estimated_arrival_time IS DISTINCT FROM OLD.estimated_arrival_time AND NEW.estimated_arrival_time IS NOT NULL) THEN
        INSERT INTO public.notifications (user_id, title, message, body, type, event_type, order_id, role)
        VALUES (v_cust_id, '🕒 Updated Arrival Time', 'Your order is expected to arrive at ' || TO_CHAR(NEW.estimated_arrival_time, 'HH12:MI AM'), 'Your order is expected to arrive at ' || TO_CHAR(NEW.estimated_arrival_time, 'HH12:MI AM'), 'order', 'ETA_UPDATE', v_order_id, 'CUSTOMER');
    END IF;

    IF (NEW.rider_lat IS NOT NULL AND NEW.delivery_address_lat IS NOT NULL AND (NEW.rider_lat != OLD.rider_lat OR NEW.rider_lng != OLD.rider_lng)) THEN
        v_dist := SQRT(POWER(NEW.rider_lat - NEW.delivery_address_lat, 2) + POWER(NEW.rider_lng - NEW.delivery_address_lng, 2)) * 111.32; -- km
        IF (v_dist < 0.3 AND (OLD.rider_lat IS NULL OR SQRT(POWER(OLD.rider_lat - NEW.delivery_address_lat, 2) + POWER(OLD.rider_lng - NEW.delivery_address_lng, 2)) * 111.32 >= 0.3)) THEN
            INSERT INTO public.notifications (user_id, title, message, body, type, event_type, order_id, role)
            VALUES (v_cust_id, '📍 Delivery Partner Nearby', 'The rider is just 300 meters away. Please be ready!', 'The rider is just 300 meters away. Please be ready!', 'delivery', 'RIDER_NEARBY', v_order_id, 'CUSTOMER');
        END IF;
    END IF;

    IF (NEW.status IS DISTINCT FROM OLD.status AND LOWER(NEW.status) = 'delivered') THEN
        INSERT INTO public.notifications (user_id, title, message, body, type, event_type, order_id, role)
        VALUES (v_cust_id, '🎉 Order Delivered', 'Enjoy your meal! 🍛 Tip your rider: ' || v_rider_name, 'Enjoy your meal! 🍛 Tip your rider: ' || v_rider_name, 'order', 'DELIVERED', v_order_id, 'CUSTOMER');
        
        INSERT INTO public.notifications (user_id, title, message, body, type, event_type, order_id, role)
        VALUES (v_rid_id, '✅ Delivery Completed', 'Great job! ₹' || v_total || ' order delivered.', 'Great job! ₹' || v_total || ' order delivered.', 'delivery', 'DELIVERY_DONE', v_order_id, 'RIDER');
    END IF;

    IF (NEW.refund_status IS DISTINCT FROM OLD.refund_status AND LOWER(NEW.refund_status) = 'initiated') THEN
        INSERT INTO public.notifications (user_id, title, message, body, type, event_type, order_id, role)
        VALUES (v_cust_id, '🔄 Refund Initiated', '₹' || v_total || ' refund has been initiated to your original payment method.', '₹' || v_total || ' refund has been initiated to your original payment method.', 'refund', 'REFUND_START', v_order_id, 'CUSTOMER');
    END IF;

    IF (NEW.refund_status IS DISTINCT FROM OLD.refund_status AND LOWER(NEW.refund_status) = 'completed') THEN
        INSERT INTO public.notifications (user_id, title, message, body, type, event_type, order_id, role)
        VALUES (v_cust_id, '✅ Refund Completed', 'Refund of ₹' || v_total || ' completed. Check your bank statement.', 'Refund of ₹' || v_total || ' completed. Check your bank statement.', 'refund', 'REFUND_DONE', v_order_id, 'CUSTOMER');
    END IF;

    IF (NEW.status IS DISTINCT FROM OLD.status AND LOWER(NEW.status) = 'cancelled') THEN
         INSERT INTO public.notifications (user_id, title, message, body, type, event_type, order_id, role)
         VALUES (v_cust_id, '⚠️ Order Cancelled', 'Your order #' || v_short_id || ' has been cancelled.', 'Your order #' || v_short_id || ' has been cancelled.', 'order', 'ORDER_CANCELLED', v_order_id, 'CUSTOMER');
    END IF;

    IF (NEW.estimated_arrival_time > (NEW.placed_at + interval '45 minutes') AND (OLD.estimated_arrival_time IS NULL OR NEW.estimated_arrival_time > OLD.estimated_arrival_time + interval '10 minutes')) THEN
         INSERT INTO public.notifications (user_id, title, message, body, type, event_type, order_id, role)
         VALUES (v_cust_id, '🐢 Possible Delay', 'Your order is taking slightly longer than expected. Thanks for patience.', 'Your order is taking slightly longer than expected. Thanks for patience.', 'order', 'DELAY', v_order_id, 'CUSTOMER');
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. CHAT MESSAGE TRIGGER
CREATE OR REPLACE FUNCTION public.proc_chat_notifications()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.notifications (user_id, title, message, body, type, event_type, order_id, role)
    VALUES (NEW.recipient_id, '💬 New Message', NEW.text, NEW.text, 'chat', 'NEW_MESSAGE', NEW.order_id::text, 'USER');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. INSTALL TRIGGERS
DROP TRIGGER IF EXISTS tr_ultimate_notifications ON public.orders;
CREATE TRIGGER tr_ultimate_notifications
AFTER INSERT OR UPDATE ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.proc_ultimate_notifications();

DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'messages') THEN
        DROP TRIGGER IF EXISTS tr_chat_notifications ON public.messages;
        CREATE TRIGGER tr_chat_notifications
        AFTER INSERT ON public.messages
        FOR EACH ROW EXECUTE FUNCTION public.proc_chat_notifications();
    END IF;
END $$;

-- 5. ENABLE REALTIME
DO $$
BEGIN
    -- Check if the publication is NOT "FOR ALL TABLES" before adding a table
    IF EXISTS (
        SELECT 1 FROM pg_publication 
        WHERE pubname = 'supabase_realtime' 
        AND puballtables = false
    ) THEN
        IF NOT EXISTS (
            SELECT 1 FROM pg_publication_tables 
            WHERE pubname = 'supabase_realtime' 
            AND schemaname = 'public' 
            AND tablename = 'notifications'
        ) THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
        END IF;
    END IF;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Realtime enable skipped: %', SQLERRM;
END $$;

-- Verify
SELECT 'ULTIMATE NOTIFICATION SYSTEM v60.0 READY!' as status;
