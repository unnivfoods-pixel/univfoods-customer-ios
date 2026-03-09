-- 🔔 CORE NOTIFICATION SYSTEM - V3 (EXACT MESSAGES)
-- Implementation of Zomato-level notification strings for Customer, Vendor, Delivery, and Admin.

BEGIN;

-- 1. TABLES (Ensuring they exist with requested structure)
CREATE TABLE IF NOT EXISTS public.notifications (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL,
    app_type text NOT NULL, -- customer / vendor / delivery / admin
    title text NOT NULL,
    message text NOT NULL,
    order_id uuid REFERENCES public.orders(id) ON DELETE CASCADE,
    type text NOT NULL, -- order / promo / alert / payout / refund
    read_status boolean DEFAULT false,
    created_at timestamptz DEFAULT now()
);

-- 2. REFINED TRIGGER LOGIC WITH EXACT USER STRINGS
CREATE OR REPLACE FUNCTION handle_core_notifications_v3()
RETURNS TRIGGER AS $$
DECLARE
    v_customer_id uuid;
    v_vendor_id uuid;
    v_delivery_id uuid;
    v_vendor_name text;
    v_rider_name text;
    v_order_short_id text;
    v_amount text;
BEGIN
    -- Context Variables
    v_order_short_id := SUBSTRING(NEW.id::text, 1, 8);
    v_customer_id := NEW.customer_id;
    v_vendor_id := NEW.vendor_id;
    v_delivery_id := NEW.delivery_partner_id;
    v_amount := NEW.total_amount::text;

    -- Fetch dynamic names
    SELECT name INTO v_vendor_name FROM public.vendors WHERE id = v_vendor_id;
    IF v_delivery_id IS NOT NULL THEN
        SELECT name INTO v_rider_name FROM public.delivery_riders WHERE id = v_delivery_id;
    END IF;

    -- ---------------------------------------------------------
    -- 🟢 SCENARIO: NEW ORDER (INSERT)
    -- ---------------------------------------------------------
    IF (TG_OP = 'INSERT') THEN
        -- CUSTOMER: Order Placed (1)
        INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
        VALUES (v_customer_id, 'customer', 'Order Confirmed 🎉', 'Your order #' || v_order_short_id || ' has been placed successfully.', NEW.id, 'order');
        
        -- VENDOR: New Order (1)
        INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
        VALUES (v_vendor_id, 'vendor', 'New Order Received 🔔', 'Order #' || v_order_short_id || ' received. Accept within 30 seconds.', NEW.id, 'order');

        -- CUSTOMER: COD Reminder (If applicable)
        IF NEW.payment_method = 'COD' THEN
            INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
            VALUES (v_customer_id, 'customer', 'Keep Cash Ready', 'Please keep ₹' || v_amount || ' ready for delivery.', NEW.id, 'order');
        END IF;

        -- ADMIN: Payment Failure (Triggered if payment_status is 'FAILED' on insert)
        IF NEW.payment_status = 'FAILED' THEN
            INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
            VALUES (v_vendor_id, 'admin', 'Payment Gateway Error', 'Payment failed for order #' || v_order_short_id || '.', NEW.id, 'alert');
        END IF;
    END IF;

    -- ---------------------------------------------------------
    -- 🔄 SCENARIO: STATUS CHANGE (UPDATE)
    -- ---------------------------------------------------------
    IF (TG_OP = 'UPDATE') THEN
        
        -- HANDLE ORDER STATUS TRANSITIONS
        IF (NEW.status != OLD.status) THEN
            CASE NEW.status
                WHEN 'CONFIRMED' THEN
                    -- CUSTOMER: Restaurant Accepted (2)
                    INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                    VALUES (v_customer_id, 'customer', 'Order Accepted 👨‍🍳', 'The restaurant has started preparing your order.', NEW.id, 'order');
                
                WHEN 'PREPARING' THEN
                    -- CUSTOMER: Preparing (4)
                    INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                    VALUES (v_customer_id, 'customer', 'Preparing Your Food', 'Your delicious meal is being prepared.', NEW.id, 'order');
                
                WHEN 'READY' THEN
                    -- DELIVERY: New Delivery Request (1)
                    -- Broad notify or internal pool logic happens here
                    -- This example inserts a generic 'delivery' notification
                    INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                    VALUES (v_vendor_id, 'delivery', 'New Delivery Available', 'Pickup from ' || COALESCE(v_vendor_name, 'Restaurant') || '. Earn ₹40. Accept now.', NEW.id, 'order');
                
                WHEN 'PICKED_UP' THEN
                    -- CUSTOMER: Out for Delivery (6)
                    INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                    VALUES (v_customer_id, 'customer', 'Out for Delivery', 'Your order is on the way. ETA: 20 mins.', NEW.id, 'order');

                    -- DELIVERY: Pickup Reminder logic would usually be a timed event, but we log the pick up completion
                
                WHEN 'DELIVERED' THEN
                    -- CUSTOMER: Delivered (7)
                    INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                    VALUES (v_customer_id, 'customer', 'Delivered Successfully', 'Order delivered. Enjoy your meal! ⭐', NEW.id, 'order');

                    -- VENDOR: Order Delivered (4)
                    INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                    VALUES (v_vendor_id, 'vendor', 'Order Delivered', 'Order #' || v_order_short_id || ' has been successfully delivered.', NEW.id, 'order');

                    -- DELIVERY: Delivery Completed (5)
                    IF v_delivery_id IS NOT NULL THEN
                        INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                        VALUES (v_delivery_id, 'delivery', 'Delivery Completed', 'Order #' || v_order_short_id || ' marked as delivered.', NEW.id, 'order');
                    END IF;

                WHEN 'CANCELLED' THEN
                    -- CHECK WHO CANCELLED (Based on your app logic, usually a flag 'cancelled_by')
                    -- Defaulting to customer/restaurant specific messages
                    
                    -- CUSTOMER: Order Cancelled (Refund logic) (3 / 8)
                    INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                    VALUES (v_customer_id, 'customer', 'Order Cancelled', 'The restaurant couldn’t accept your order. Refund initiated if applicable.', NEW.id, 'order');
                    
                    -- VENDOR: Order Cancelled (2)
                    INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                    VALUES (v_vendor_id, 'vendor', 'Order Cancelled', 'Order #' || v_order_short_id || ' has been cancelled by customer.', NEW.id, 'order');

                    -- DELIVERY: Order Cancelled (2)
                    IF v_delivery_id IS NOT NULL THEN
                        INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                        VALUES (v_delivery_id, 'delivery', 'Delivery Cancelled', 'Order #' || v_order_short_id || ' has been cancelled.', NEW.id, 'order');
                    END IF;

                ELSE
                    -- Do nothing for other statuses
            END CASE;
        END IF;

        -- HANDLE ASSIGNMENT CHANGE
        IF (NEW.delivery_partner_id IS NOT NULL AND (OLD.delivery_partner_id IS NULL OR OLD.delivery_partner_id != NEW.delivery_partner_id)) THEN
            -- CUSTOMER: Rider Assigned (5)
            INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
            VALUES (v_customer_id, 'customer', 'Rider Assigned 🚴', COALESCE(v_rider_name, 'Rider') || ' will deliver your order. Track live now.', NEW.id, 'order');
            
            -- VENDOR: Delivery Assigned (3)
            INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
            VALUES (v_vendor_id, 'vendor', 'Delivery Partner Assigned', COALESCE(v_rider_name, 'Rider') || ' will pick up order #' || v_order_short_id || '.', NEW.id, 'order');
        END IF;

        -- HANDLE REFUND TRIGGERS (Based on status change or specialized columns)
        IF (NEW.payment_status = 'REFUNDED' AND OLD.payment_status != 'REFUNDED') THEN
            -- CUSTOMER: Refund Completed (10)
            INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
            VALUES (v_customer_id, 'customer', 'Refund Successful', '₹' || v_amount || ' has been credited successfully.', NEW.id, 'refund');
        END IF;

    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. REBIND TRIGGER
DROP TRIGGER IF EXISTS tr_core_notifications ON public.orders;
CREATE TRIGGER tr_core_notifications
AFTER INSERT OR UPDATE ON public.orders
FOR EACH ROW
EXECUTE FUNCTION handle_core_notifications_v3();

-- 4. ADDITIONAL SPECIFIC LOGIC FOR VENDORS/DELIVERY (Payments/Stock)
-- These scenarios often happen in other tables. I will add helper functions for them.

CREATE OR REPLACE FUNCTION admin_trigger_flash_sale(p_message text DEFAULT 'Order now and save big. Limited time offer.')
RETURNS void AS $$
BEGIN
    INSERT INTO public.notifications (user_id, app_type, title, message, type)
    SELECT id, 'customer', '50% OFF Today Only!', p_message, 'promo'
    FROM public.customer_profiles;
END;
$$ LANGUAGE plpgsql;

COMMIT;
