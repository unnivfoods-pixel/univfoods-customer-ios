-- 🛡️ STABILIZE_NOTIFICATIONS_V17.sql
-- This script fixes the schema discrepancy and activates automated alerts.

-- 1. FIX SCHEMA: Add target_type if it doesn't exist
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='notifications' AND column_name='target_type') THEN
        ALTER TABLE public.notifications ADD COLUMN target_type text DEFAULT 'specific';
    END IF;
END $$;

-- 2. Ensure RLS allows users to see their own notifications
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can see their own notifications" ON public.notifications;
CREATE POLICY "Users can see their own notifications"
ON public.notifications FOR SELECT
USING (auth.uid() = user_id OR user_id IS NULL OR target_type = 'all' OR target_type = 'admin');

DROP POLICY IF EXISTS "Admin can insert notifications" ON public.notifications;
CREATE POLICY "Admin can insert notifications"
ON public.notifications FOR INSERT
WITH CHECK (true);

-- 3. Trigger to notify customer when order status changes
CREATE OR REPLACE FUNCTION notify_customer_on_order_update()
RETURNS TRIGGER AS $$
DECLARE
    v_title TEXT;
    v_body TEXT;
BEGIN
    -- Only notify if status has actually changed
    IF (OLD.status IS DISTINCT FROM NEW.status) THEN
        CASE NEW.status
            WHEN 'accepted' THEN
                v_title := 'Order Accepted! 🍛';
                v_body := 'The restaurant has started preparing your delicious meal.';
            WHEN 'preparing' THEN
                v_title := 'Cooking in Progress... 🔥';
                v_body := 'Your food is sizzling in the kitchen.';
            WHEN 'ready' THEN
                v_title := 'Order Ready! ✅';
                v_body := 'Your meal is packed and waiting for the rider.';
            WHEN 'rider_assigned' THEN
                v_title := 'Rider on the Way! 🛵';
                v_body := 'A delivery partner has been assigned to your order.';
            WHEN 'on_the_way' THEN
                v_title := 'Food is En Route! 🏃‍♂️';
                v_body := 'Your rider is heading to your location.';
            WHEN 'out_for_delivery' THEN
                v_title := 'Almost There! 📍';
                v_body := 'Your order is nearby and will arrive in minutes.';
            WHEN 'delivered' THEN
                v_title := 'Enjoy your Meal! 🍱';
                v_body := 'Your order has been successfully delivered.';
            WHEN 'cancelled' THEN
                v_title := 'Order Cancelled ❌';
                v_body := 'Unfortunately, your order was cancelled.';
            ELSE
                v_title := 'Order Update';
                v_body := 'Your order status is now: ' || NEW.status;
        END CASE;

        -- Insert into notifications table
        INSERT INTO public.notifications (user_id, title, body, role, target_type, order_id)
        VALUES (NEW.customer_id, v_title, v_body, 'CUSTOMER', 'specific', NEW.id);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_order_status_notification ON public.orders;
CREATE TRIGGER tr_order_status_notification
AFTER UPDATE ON public.orders
FOR EACH ROW
EXECUTE FUNCTION notify_customer_on_order_update();

-- 4. Trigger to notify Admin on New Order
CREATE OR REPLACE FUNCTION notify_admin_on_new_order()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.notifications (target_type, title, body, role, order_id)
    VALUES ('admin', 'New Order Received! 🛍️', 'Order ID: ' || SUBSTRING(NEW.id::text, 1, 8), 'ADMIN', NEW.id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_new_order_admin_notification ON public.orders;
CREATE TRIGGER tr_new_order_admin_notification
AFTER INSERT ON public.orders
FOR EACH ROW
EXECUTE FUNCTION notify_admin_on_new_order();
