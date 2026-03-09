-- 🚀 FINAL NOTIFICATION STABILIZATION v71
-- This script fixes the column mismatch and ensures all apps receive notifications properly.

BEGIN;

-- 1. Ensure Notifications Table has all required columns for all apps
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS body TEXT;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS message TEXT;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS event_type TEXT;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS user_role TEXT;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS type TEXT DEFAULT 'ORDER_STATUS';
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS target_type TEXT DEFAULT 'specific';

-- 2. Backfill existing data so no app shows empty notifications
UPDATE public.notifications SET message = body WHERE message IS NULL AND body IS NOT NULL;
UPDATE public.notifications SET body = message WHERE body IS NULL AND message IS NOT NULL;

-- 3. Unified Notification Trigger Function
-- Watches BOTH 'status' and 'order_status' to be 100% resilient
CREATE OR REPLACE FUNCTION public.fn_unified_notification_v71()
RETURNS TRIGGER AS $$
DECLARE
    v_shop_name TEXT;
    v_customer_name TEXT;
    v_rider_name TEXT;
    v_title TEXT;
    v_message TEXT;
    v_type TEXT := 'ORDER_STATUS';
    v_event_type TEXT := 'INFO';
    v_current_status TEXT;
    v_role TEXT;
BEGIN
    -- Determine the effective status (prefer status, fallback to order_status)
    v_current_status := COALESCE(NEW.status, NEW.order_status);

    -- NO-OP if status hasn't changed
    IF (TG_OP = 'UPDATE') THEN
        IF (COALESCE(OLD.status, 'EMPTY') = COALESCE(NEW.status, 'EMPTY') AND 
            COALESCE(OLD.order_status, 'EMPTY') = COALESCE(NEW.order_status, 'EMPTY')) THEN
            RETURN NEW;
        END IF;
    END IF;

    -- Get Context Names
    SELECT COALESCE(name, 'The Restaurant') INTO v_shop_name FROM public.vendors WHERE (id::text) = (NEW.vendor_id::text);
    SELECT COALESCE(full_name, 'Customer') INTO v_customer_name FROM public.customer_profiles WHERE (id::text) = (NEW.customer_id::text);
    
    -- Notification Logic based on Status
    CASE UPPER(v_current_status)
        WHEN 'PLACED', 'PENDING' THEN
            -- Notify Vendor
            INSERT INTO public.notifications (user_id, user_role, role, title, body, message, order_id, type, event_type, priority)
            VALUES (NEW.vendor_id, 'vendor', 'VENDOR', 'New Order Received! 🍛', 
                    'Order from ' || v_customer_name || ' (₹' || NEW.total || ')',
                    'Order from ' || v_customer_name || ' (₹' || NEW.total || ')',
                    NEW.id, 'ORDER_STATUS', 'ORDER_NEW', 'HIGH');
            
            -- Notify Customer
            INSERT INTO public.notifications (user_id, user_role, role, title, body, message, order_id, type, event_type)
            VALUES (NEW.customer_id, 'customer', 'CUSTOMER', 'Order Placed! 🎉', 
                    'Your order has been placed successfully.',
                    'Your order has been placed successfully.',
                    NEW.id, 'ORDER_STATUS', 'ORDER_PLACED');

        WHEN 'ACCEPTED', 'CONFIRMED' THEN
            -- Notify Customer
            INSERT INTO public.notifications (user_id, user_role, role, title, body, message, order_id, type, event_type)
            VALUES (NEW.customer_id, 'customer', 'CUSTOMER', 'Order Accepted! ✅', 
                    v_shop_name || ' has accepted your order.',
                    v_shop_name || ' has accepted your order.',
                    NEW.id, 'ORDER_STATUS', 'ORDER_ACCEPTED');

        WHEN 'PREPARING' THEN
            -- Notify Customer
            INSERT INTO public.notifications (user_id, user_role, role, title, body, message, order_id, type, event_type)
            VALUES (NEW.customer_id, 'customer', 'CUSTOMER', 'Cooking... 👨‍🍳', 
                    'Your food is being prepared.',
                    'Your food is being prepared.',
                    NEW.id, 'ORDER_STATUS', 'ORDER_PREPARING');

        WHEN 'READY_FOR_PICKUP', 'READY' THEN
            -- Notify Customer
            INSERT INTO public.notifications (user_id, user_role, role, title, body, message, order_id, type, event_type)
            VALUES (NEW.customer_id, 'customer', 'CUSTOMER', 'Order Ready! 📦', 
                    'Your food is ready for pickup.',
                    'Your food is ready for pickup.',
                    NEW.id, 'ORDER_STATUS', 'ORDER_READY');
            
            -- Notify Rider if assigned
            IF (NEW.rider_id IS NOT NULL OR NEW.delivery_partner_id IS NOT NULL) THEN
                INSERT INTO public.notifications (user_id, user_role, role, title, body, message, order_id, type, event_type, priority)
                VALUES (COALESCE(NEW.rider_id, NEW.delivery_partner_id), 'delivery', 'RIDER', 'Pickup Ready! 🛵', 
                        'Order #' || LEFT(NEW.id::text, 8) || ' is ready at ' || v_shop_name,
                        'Order #' || LEFT(NEW.id::text, 8) || ' is ready at ' || v_shop_name,
                        NEW.id, 'ORDER_STATUS', 'ORDER_READY', 'HIGH');
            END IF;

        WHEN 'RIDER_ASSIGNED', 'PICKING_UP' THEN
            -- Notify Customer
            INSERT INTO public.notifications (user_id, user_role, role, title, body, message, order_id, type, event_type)
            VALUES (NEW.customer_id, 'customer', 'CUSTOMER', 'Rider Assigned 🏍️', 
                    'A delivery partner is heading to the restaurant.',
                    'A delivery partner is heading to the restaurant.',
                    NEW.id, 'ORDER_STATUS', 'ORDER_RIDER');
            
            -- Notify Rider
            IF (COALESCE(NEW.rider_id, NEW.delivery_partner_id) IS NOT NULL) THEN
                INSERT INTO public.notifications (user_id, user_role, role, title, body, message, order_id, type, event_type, priority)
                VALUES (COALESCE(NEW.rider_id, NEW.delivery_partner_id), 'delivery', 'RIDER', 'New Mission! 🛵', 
                        'You have been assigned to pick up from ' || v_shop_name,
                        'You have been assigned to pick up from ' || v_shop_name,
                        NEW.id, 'ORDER_STATUS', 'ORDER_ASSIGNED', 'HIGH');
            END IF;

        WHEN 'PICKED_UP', 'ON_THE_WAY', 'OUT_FOR_DELIVERY' THEN
            -- Notify Customer
            INSERT INTO public.notifications (user_id, user_role, role, title, body, message, order_id, type, event_type)
            VALUES (NEW.customer_id, 'customer', 'CUSTOMER', 'Out for Delivery! 🚀', 
                    'Your food is on the way to you.',
                    'Your food is on the way to you.',
                    NEW.id, 'ORDER_STATUS', 'ORDER_TRANSIT');

        WHEN 'DELIVERED', 'COMPLETED' THEN
            -- Notify Customer
            INSERT INTO public.notifications (user_id, user_role, role, title, body, message, order_id, type, event_type)
            VALUES (NEW.customer_id, 'customer', 'CUSTOMER', 'Order Delivered! 🍛', 
                    'Enjoy your meal! Please rate your experience.',
                    'Enjoy your meal! Please rate your experience.',
                    NEW.id, 'ORDER_STATUS', 'ORDER_DELIVERED');
            
            -- Notify Vendor
            INSERT INTO public.notifications (user_id, user_role, role, title, body, message, order_id, type, event_type)
            VALUES (NEW.vendor_id, 'vendor', 'VENDOR', 'Order Completed! ✅', 
                    'Order #' || LEFT(NEW.id::text, 8) || ' was delivered successfully.',
                    'Order #' || LEFT(NEW.id::text, 8) || ' was delivered successfully.',
                    NEW.id, 'ORDER_STATUS', 'ORDER_COMPLETED');

        WHEN 'CANCELLED', 'REJECTED' THEN
            -- Notify Customer
            INSERT INTO public.notifications (user_id, user_role, role, title, body, message, order_id, type, event_type)
            VALUES (NEW.customer_id, 'customer', 'CUSTOMER', 'Order Cancelled ❌', 
                    'Unfortunately, your order could not be fulfilled.',
                    'Unfortunately, your order could not be fulfilled.',
                    NEW.id, 'ORDER_STATUS', 'ORDER_CANCELLED');
        ELSE
            -- No notification for other statuses
    END CASE;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Clean up old triggers to avoid duplicates
DROP TRIGGER IF EXISTS on_order_placed ON public.orders;
DROP TRIGGER IF EXISTS on_order_status_changed ON public.orders;
DROP TRIGGER IF EXISTS on_rider_assigned ON public.orders;
DROP TRIGGER IF EXISTS on_payment_status_changed ON public.orders;
DROP TRIGGER IF EXISTS tr_order_status_notification ON public.orders;
DROP TRIGGER IF EXISTS tr_new_order_admin_notification ON public.orders;
DROP TRIGGER IF EXISTS tr_order_notifications ON public.orders;

-- 5. Attach the new Super Trigger
CREATE TRIGGER tr_unified_notifications_v71
AFTER INSERT OR UPDATE ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.fn_unified_notification_v71();

-- 6. RPC for marking as read (Ensuring it works with multiple user_id types)
CREATE OR REPLACE FUNCTION public.mark_notif_read_v71(p_notif_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE public.notifications 
    SET is_read = TRUE 
    WHERE id = p_notif_id 
    AND (user_id::TEXT = auth.uid()::TEXT OR user_id::TEXT = auth.jwt() ->> 'sub');
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
