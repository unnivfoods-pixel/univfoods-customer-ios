-- 🔔 CORE NOTIFICATION SYSTEM ARCHITECTURE - V2
-- This script implements the Zomato-level Realtime Notification System.

BEGIN;

-- 1. NOTIFICATIONS LOG TABLE
-- Exact structure as requested: id, user_id, app_type, title, message, order_id, type, read_status, created_at
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

-- 2. CENTRAL FCM TOKEN STORAGE
-- To track multiple devices and app types per user
CREATE TABLE IF NOT EXISTS public.user_fcm_tokens (
    user_id uuid NOT NULL,
    app_type text NOT NULL, -- customer / vendor / delivery / admin
    fcm_token text NOT NULL,
    device_id text, -- Optional: helps handle "Update token if user logs in new device"
    updated_at timestamptz DEFAULT now(),
    PRIMARY KEY (user_id, app_type, fcm_token)
);

-- 3. REALTIME LOGIC: ORDER LIFECYCLE TRIGGERS
-- Re-implementing the 10 customer scenarios, 5 vendor scenarios, and 4 delivery scenarios

CREATE OR REPLACE FUNCTION handle_core_notifications()
RETURNS TRIGGER AS $$
DECLARE
    v_customer_id uuid;
    v_vendor_id uuid;
    v_delivery_id uuid;
    v_vendor_name text;
    v_rider_name text;
    v_order_short_id text;
BEGIN
    v_order_short_id := SUBSTRING(NEW.id::text, 1, 8);
    v_customer_id := NEW.customer_id;
    v_vendor_id := NEW.vendor_id;
    v_delivery_id := NEW.delivery_partner_id;

    -- Get names for better messages
    SELECT name INTO v_vendor_name FROM public.vendors WHERE id = v_vendor_id;
    IF v_delivery_id IS NOT NULL THEN
        SELECT name INTO v_rider_name FROM public.delivery_riders WHERE id = v_delivery_id;
    END IF;

    -- SCENARIO: NEW ORDER (INSERT)
    IF (TG_OP = 'INSERT') THEN
        -- 🟢 CUSTOMER: Order Placed
        INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
        VALUES (v_customer_id, 'customer', 'Order Placed!', 'Your order has been placed successfully.', NEW.id, 'order');
        
        -- 🟡 VENDOR: New Order
        INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
        VALUES (v_vendor_id, 'vendor', 'New Order Received', 'New order received. Accept within 30 seconds.', NEW.id, 'order');
    END IF;

    -- SCENARIO: STATUS CHANGE (UPDATE)
    IF (TG_OP = 'UPDATE') THEN
        IF (NEW.status != OLD.status) THEN
            
            CASE NEW.status
                -- 🟢 CUSTOMER: Vendor Accepted
                WHEN 'CONFIRMED' THEN
                    INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                    VALUES (v_customer_id, 'customer', 'Order Accepted', 'Restaurant has accepted your order.', NEW.id, 'order');
                
                -- 🟢 CUSTOMER: Preparing
                WHEN 'PREPARING' THEN
                    INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                    VALUES (v_customer_id, 'customer', 'Preparing Food', 'Your food is being prepared.', NEW.id, 'order');
                
                -- 🔵 DELIVERY: New Delivery Request (Wait for nearby logic in backend, but notify assigned if ready)
                WHEN 'READY' THEN
                    -- Notification to nearby riders (This part usually requires a separate function, 
                    -- but for the "Ready" status, we notify system/nearby)
                    INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                    VALUES (v_vendor_id, 'admin', 'Order Ready', 'Order #' || v_order_short_id || ' is ready for pickup.', NEW.id, 'alert');
                    
                    -- Note: Scenario 5 (Customer does NOT get "Ready")
                
                -- 🟢 CUSTOMER: Out for Delivery (Picked Up)
                WHEN 'PICKED_UP' THEN
                    INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                    VALUES (v_customer_id, 'customer', 'Out for Delivery', 'Your order is out for delivery. Track live now.', NEW.id, 'order');
                    
                    INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                    VALUES (v_vendor_id, 'vendor', 'Order Picked Up', 'Delivery partner has picked up order #' || v_order_short_id, NEW.id, 'order');

                -- 🟢 CUSTOMER: Delivered
                WHEN 'DELIVERED' THEN
                    INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                    VALUES (v_customer_id, 'customer', 'Delivered!', 'Order delivered successfully. Enjoy your meal!', NEW.id, 'order');

                -- 🟢 CUSTOMER 🟠 VENDOR 🔵 DELIVERY: Cancelled
                WHEN 'CANCELLED' THEN
                    INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                    VALUES (v_customer_id, 'customer', 'Order Cancelled', 'Your order has been cancelled.', NEW.id, 'order');
                    
                    INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                    VALUES (v_vendor_id, 'vendor', 'Order Cancelled', 'Order has been cancelled.', NEW.id, 'order');
                    
                    IF v_delivery_id IS NOT NULL THEN
                        INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                        VALUES (v_delivery_id, 'delivery', 'Delivery Cancelled', 'Order #' || v_order_short_id || ' has been cancelled.', NEW.id, 'order');
                    END IF;

                ELSE
                    -- Custom status handling if needed
            END CASE;
        END IF;

        -- 🟢 CUSTOMER: Delivery Partner Assigned
        IF (NEW.delivery_partner_id IS NOT NULL AND OLD.delivery_partner_id IS NULL) THEN
            INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
            VALUES (v_customer_id, 'customer', 'Rider Assigned', COALESCE(v_rider_name, 'Ramesh') || ' is on the way to pick up your order.', NEW.id, 'order');
            
            INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
            VALUES (v_vendor_id, 'vendor', 'Rider Assigned', 'Delivery partner assigned for order #' || v_order_short_id, NEW.id, 'order');
            
            -- 🔵 DELIVERY: New Delivery Request (Assigned)
            INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
            VALUES (NEW.delivery_partner_id, 'delivery', 'New Delivery Assigned', 'You have been assigned order #' || v_order_short_id, NEW.id, 'order');
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. APPLY TRIGGERS
DROP TRIGGER IF EXISTS tr_core_notifications ON public.orders;
CREATE TRIGGER tr_core_notifications
AFTER INSERT OR UPDATE ON public.orders
FOR EACH ROW
EXECUTE FUNCTION handle_core_notifications();

-- 5. RLS & PERMISSIONS
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_fcm_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can see their own notifications" ON public.notifications;
CREATE POLICY "Users can see their own notifications" ON public.notifications
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can manage their own tokens" ON public.user_fcm_tokens;
CREATE POLICY "Users can manage their own tokens" ON public.user_fcm_tokens
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 6. REALTIME REGISTRATION
-- Add notifications to the realtime publication
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;

COMMIT;
