-- 🛡️ STABILIZE_NOTIFICATIONS_V15.sql
-- This script ensures the notifications table is enabled for Realtime
-- and adds a trigger to automatically send notifications when an order status changes.

-- 1. Enable Realtime for notifications
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;

-- 2. Ensure RLS allows users to see their own notifications
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can see their own notifications" ON notifications;
CREATE POLICY "Users can see their own notifications"
ON notifications FOR SELECT
USING (auth.uid() = user_id OR user_id IS NULL OR target_type = 'all');

DROP POLICY IF EXISTS "Admin can insert notifications" ON notifications;
CREATE POLICY "Admin can insert notifications"
ON notifications FOR INSERT
WITH CHECK (true); -- Usually admin tokens/service role bypass RLS anyway

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
                v_body := 'Unfortunately, your order was cancelled. Please check details.';
            ELSE
                v_title := 'Order Update';
                v_body := 'Your order status is now: ' || NEW.status;
        END CASE;

        -- Insert into notifications table (Realtime Hub will pick this up)
        INSERT INTO notifications (user_id, title, body, category, status, order_id)
        VALUES (NEW.customer_id, v_title, v_body, 'ALERT', 'unread', NEW.id);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_order_status_notification ON orders;
CREATE TRIGGER tr_order_status_notification
AFTER UPDATE ON orders
FOR EACH ROW
EXECUTE FUNCTION notify_customer_on_order_update();

-- 4. Trigger to notify Admin on New Order
CREATE OR REPLACE FUNCTION notify_admin_on_new_order()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO notifications (target_type, title, body, category, status, order_id)
    VALUES ('admin', 'New Order Received! 🛍️', 'A new order has been placed: ' || NEW.id, 'ALERT', 'unread', NEW.id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_new_order_admin_notification ON orders;
CREATE TRIGGER tr_new_order_admin_notification
AFTER INSERT ON orders
FOR EACH ROW
EXECUTE FUNCTION notify_admin_on_new_order();
