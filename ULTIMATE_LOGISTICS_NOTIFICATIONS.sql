-- 🚀 MASTER NOTIFICATION ENGINE v4.0 (ULTIMATE LOGISTICS)
-- Corrects every scenario for Customer, Vendor, and Delivery apps.

BEGIN;

-- 1. DROP OLD ENGINE
DROP TRIGGER IF EXISTS tr_master_notifications ON public.orders;

-- 2. ENSURE TABLES ARE READY
ALTER TABLE IF EXISTS public.notifications ALTER COLUMN user_id TYPE text USING user_id::text;
ALTER TABLE IF EXISTS public.notifications ALTER COLUMN order_id TYPE text USING order_id::text;
ALTER TABLE public.notifications REPLICA IDENTITY FULL;

-- 3. THE PRO ENGINE
CREATE OR REPLACE FUNCTION public.master_notification_handler()
RETURNS TRIGGER AS $$
DECLARE
    v_c_id text := NEW.customer_id::text;
    v_v_id text := NEW.vendor_id::text;
    v_r_id text := NEW.rider_id::text;
    v_s_id text := SUBSTRING(NEW.id::text, 1, 8);
    v_rest_name text;
    v_cust_name text;
    v_ride_name text;
    v_amt text := COALESCE(NEW.total_amount::text, '0');
BEGIN
    -- FETCH DATA
    SELECT name INTO v_rest_name FROM public.vendors WHERE id::text = v_v_id;
    SELECT full_name INTO v_cust_name FROM public.customer_profiles WHERE id::text = v_c_id;
    IF v_r_id IS NOT NULL THEN
        SELECT name INTO v_ride_name FROM public.riders WHERE id::text = v_r_id;
    END IF;

    v_rest_name := COALESCE(v_rest_name, 'The Restaurant');
    v_cust_name := COALESCE(v_cust_name, 'Customer');
    v_ride_name := COALESCE(v_ride_name, 'Delivery Partner');

    -- 🛒 NEW ORDER (ON INSERT)
    IF (TG_OP = 'INSERT') THEN
        -- Customer
        INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
        VALUES (v_c_id, 'customer', '✅ Order Placed Successfully', 'Your order #' || v_s_id || ' has been sent to ' || v_rest_name || '.', NEW.id::text, 'order');
        -- Vendor
        INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
        VALUES (v_v_id, 'vendor', '🆕 New Order Received', 'Order #' || v_s_id || ' from ' || v_cust_name || '. Accept within 60 seconds.', NEW.id::text, 'order');
    END IF;

    -- 🔄 STATUS UPDATES
    IF (TG_OP = 'UPDATE' AND NEW.status IS DISTINCT FROM OLD.status) THEN
        
        -- CUSTOMER FLOW
        CASE LOWER(NEW.status)
            WHEN 'accepted' THEN
                INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                VALUES (v_c_id, 'customer', '🍳 Restaurant Accepted Your Order', v_rest_name || ' has started preparing your food.', NEW.id::text, 'order');
            WHEN 'cancelled' THEN
                IF OLD.status = 'pending' THEN
                    INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                    VALUES (v_c_id, 'customer', '❌ Order Cancelled by Restaurant', v_rest_name || ' could not accept your order. Refund initiated.', NEW.id::text, 'order');
                ELSE
                    INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                    VALUES (v_c_id, 'customer', '⚠️ Order Cancelled', 'Your order #' || v_s_id || ' has been cancelled successfully.', NEW.id::text, 'order');
                END IF;
            WHEN 'preparing' THEN
                INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                VALUES (v_c_id, 'customer', '👨‍🍳 Preparing Food', v_rest_name || ' is cooking your meal.', NEW.id::text, 'order');
            WHEN 'ready' THEN
                IF v_r_id IS NOT NULL THEN
                    INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                    VALUES (v_c_id, 'customer', '🛵 Delivery Partner Assigned', v_ride_name || ' is on the way to pick up your order.', NEW.id::text, 'order');
                END IF;
            WHEN 'picked_up' THEN
                INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                VALUES (v_c_id, 'customer', '📦 Order Picked Up', 'Your order is on the way! Track live now.', NEW.id::text, 'order');
            WHEN 'near_location' THEN
                INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                VALUES (v_c_id, 'customer', '📍 Delivery Partner Near You', 'Your order will arrive in a few minutes.', NEW.id::text, 'order');
            WHEN 'delivered' THEN
                INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                VALUES (v_c_id, 'customer', '🎉 Order Delivered', 'Enjoy your meal! Don’t forget to rate your experience.', NEW.id::text, 'order');
            ELSE NULL;
        END CASE;

        -- VENDOR FLOW
        CASE LOWER(NEW.status)
            WHEN 'ready' THEN
                 IF v_r_id IS NOT NULL THEN
                    INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                    VALUES (v_v_id, 'vendor', '🛵 Delivery Partner Assigned', v_ride_name || ' will pick up order #' || v_s_id || '.', NEW.id::text, 'order');
                 END IF;
            WHEN 'delivered' THEN
                INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                VALUES (v_v_id, 'vendor', '✅ Order Completed', 'Order #' || v_s_id || ' delivered successfully.', NEW.id::text, 'order');
            ELSE NULL;
        END CASE;

        -- DELIVERY FLOW
        IF v_r_id IS NOT NULL THEN
            CASE LOWER(NEW.status)
                WHEN 'ready' THEN 
                    INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                    VALUES (v_r_id, 'delivery', '🛵 Order Assigned', 'Proceed to ' || v_rest_name || ' for pickup.', NEW.id::text, 'order');
                WHEN 'picked_up' THEN
                     INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                     VALUES (v_r_id, 'delivery', '📍 Pickup Confirmed', 'Deliver order to customer address.', NEW.id::text, 'order');
                WHEN 'cancelled' THEN
                     INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                     VALUES (v_r_id, 'delivery', '❌ Order Cancelled', 'Delivery cancelled. Check compensation details.', NEW.id::text, 'delivery');
                ELSE NULL;
            END CASE;
        END IF;

    END IF;

    -- 💰 PAYMENT LOGIC
    IF (TG_OP = 'UPDATE' AND NEW.payment_status IS DISTINCT FROM OLD.payment_status AND NEW.payment_status = 'paid') THEN
        INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
        VALUES (v_c_id, 'customer', '💳 Payment Successful', '₹' || v_amt || ' received for order #' || v_s_id || '.', NEW.id::text, 'payment');
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. RE-INSTALL
CREATE TRIGGER tr_master_notifications
AFTER INSERT OR UPDATE ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.master_notification_handler();

COMMIT;

SELECT 'SUPER NOTIFICATION ENGINE v4.0 ACTIVE!' as status;
