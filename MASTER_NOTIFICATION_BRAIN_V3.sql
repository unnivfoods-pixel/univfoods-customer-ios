-- 🚀 THE MASTER NOTIFICATION ENGINE (v3.0)
-- Implementing the EXACT messages for Customer, Vendor, and Delivery Apps.

BEGIN;

-- 1. CLEANUP OLD ENGINE
DROP TRIGGER IF EXISTS tr_master_notifications ON public.orders;

-- 2. THE LOGISTICS BRAIN
CREATE OR REPLACE FUNCTION public.master_notification_handler()
RETURNS TRIGGER AS $$
DECLARE
    v_customer_id text := NEW.customer_id::text;
    v_vendor_id text := NEW.vendor_id::text;
    v_rider_id text := NEW.rider_id::text;
    v_short_id text := SUBSTRING(NEW.id::text, 1, 8);
    v_vendor_name text;
    v_customer_name text;
    v_rider_name text;
    v_amount text := COALESCE(NEW.total_amount::text, '0');
BEGIN
    -- FETCH NAMES FOR PLACEHOLDERS
    SELECT name INTO v_vendor_name FROM public.vendors WHERE id::text = v_vendor_id;
    SELECT full_name INTO v_customer_name FROM public.customer_profiles WHERE id::text = v_customer_id;
    IF v_rider_id IS NOT NULL THEN
        SELECT name INTO v_rider_name FROM public.riders WHERE id::text = v_rider_id;
    END IF;

    v_vendor_name := COALESCE(v_vendor_name, 'The Restaurant');
    v_customer_name := COALESCE(v_customer_name, 'Customer');
    v_rider_name := COALESCE(v_rider_name, 'Delivery Partner');

    -- 🛒 NEW ORDER PLACED (TRIGGERED ON INSERT)
    IF (TG_OP = 'INSERT') THEN
        -- 1. Customer: Order Placed
        INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
        VALUES (v_customer_id, 'customer', '✅ Order Placed Successfully', 'Your order #' || v_short_id || ' has been sent to ' || v_vendor_name || '.', NEW.id::text, 'order');
        
        -- 2. Vendor: New Order
        INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
        VALUES (v_vendor_id, 'vendor', '🆕 New Order Received', 'Order #' || v_short_id || ' from ' || v_customer_name || '. Accept within 60 seconds.', NEW.id::text, 'order');
    END IF;

    -- 🔄 STATUS UPDATES
    IF (TG_OP = 'UPDATE' AND NEW.status IS DISTINCT FROM OLD.status) THEN
        
        -- CUSTOMER NOTIFICATIONS
        CASE LOWER(NEW.status)
            WHEN 'accepted' THEN
                INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                VALUES (v_customer_id, 'customer', '🍳 Restaurant Accepted Your Order', v_vendor_name || ' has started preparing your food.', NEW.id::text, 'order');
            WHEN 'cancelled' THEN
                IF OLD.status = 'pending' THEN -- Restaurant Rejected
                   INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                   VALUES (v_customer_id, 'customer', '❌ Order Cancelled by Restaurant', v_vendor_name || ' could not accept your order. Refund initiated.', NEW.id::text, 'order');
                ELSE -- General Cancellation
                   INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                   VALUES (v_customer_id, 'customer', '⚠️ Order Cancelled', 'Your order #' || v_short_id || ' has been cancelled successfully.', NEW.id::text, 'order');
                END IF;
            WHEN 'preparing' THEN
                -- No specific message in the list, but good to have
                INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                VALUES (v_customer_id, 'customer', '👨‍🍳 Preparing Food', v_vendor_name || ' is cooking your meal.', NEW.id::text, 'order');
            WHEN 'ready' THEN
                -- If rider assigned, notify customer
                IF v_rider_id IS NOT NULL THEN
                    INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                    VALUES (v_customer_id, 'customer', '🛵 Delivery Partner Assigned', v_rider_name || ' is on the way to pick up your order.', NEW.id::text, 'order');
                END IF;
            WHEN 'picked_up' THEN
                INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                VALUES (v_customer_id, 'customer', '📦 Order Picked Up', 'Your order is on the way! Track live now.', NEW.id::text, 'order');
            WHEN 'near_location' THEN
                INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                VALUES (v_customer_id, 'customer', '📍 Delivery Partner Near You', 'Your order will arrive in a few minutes.', NEW.id::text, 'order');
            WHEN 'delivered' THEN
                INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                VALUES (v_customer_id, 'customer', '🎉 Order Delivered', 'Enjoy your meal! Don’t forget to rate your experience.', NEW.id::text, 'order');
            ELSE NULL;
        END CASE;

        -- VENDOR NOTIFICATIONS ON UPDATE
        CASE LOWER(NEW.status)
            WHEN 'cancelled' THEN
                INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                VALUES (v_vendor_id, 'vendor', '❌ Customer Cancelled Order', 'Order #' || v_short_id || ' has been cancelled.', NEW.id::text, 'order');
            WHEN 'ready' THEN
                IF v_rider_id IS NOT NULL THEN
                    INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                    VALUES (v_vendor_id, 'vendor', '🛵 Delivery Partner Assigned', v_rider_name || ' will pick up order #' || v_short_id || '.', NEW.id::text, 'order');
                END IF;
            WHEN 'delivered' THEN
                INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                VALUES (v_vendor_id, 'vendor', '✅ Order Completed', 'Order #' || v_short_id || ' delivered successfully.', NEW.id::text, 'order');
            ELSE NULL;
        END CASE;
        
        -- DELIVERY NOTIFICATIONS
        IF v_rider_id IS NOT NULL THEN
            CASE LOWER(NEW.status)
                WHEN 'ready' THEN -- Assigned to Rider
                    INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                    VALUES (v_rider_id, 'delivery', '🛵 Order Assigned', 'Proceed to ' || v_vendor_name || ' for pickup.', NEW.id::text, 'order');
                WHEN 'picked_up' THEN
                    INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                    VALUES (v_rider_id, 'delivery', '📍 Pickup Confirmed', 'Deliver order to customer address.', NEW.id::text, 'order');
                WHEN 'cancelled' THEN
                    INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                    VALUES (v_rider_id, 'delivery', '❌ Order Cancelled', 'Delivery cancelled. Check compensation details.', NEW.id::text, 'order');
                ELSE NULL;
            END CASE;
        END IF;

    END IF;

    -- 💰 PAYMENT HANDLING (IF PAID STATUS CHANGES)
    IF (TG_OP = 'UPDATE' AND NEW.payment_status IS DISTINCT FROM OLD.payment_status AND NEW.payment_status = 'paid') THEN
        INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
        VALUES (v_customer_id, 'customer', '💳 Payment Successful', '₹' || v_amount || ' received for order #' || v_short_id || '.', NEW.id::text, 'payment');
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. ACTIVATE
CREATE TRIGGER tr_master_notifications
AFTER INSERT OR UPDATE ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.master_notification_handler();

COMMIT;

SELECT 'Master Notification Brain v3.0 Installed!' as status;
