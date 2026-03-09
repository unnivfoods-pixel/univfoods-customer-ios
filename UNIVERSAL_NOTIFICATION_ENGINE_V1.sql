-- MISSION: UNIVERSAL NOTIFICATION ENGINE V1
-- Description: Centralized notification system with backend-only triggers for Customer, Vendor, Delivery, and Admin.

-- 1. Notifications Table
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL, -- Flexible ID to handle different roles
    user_role TEXT NOT NULL CHECK (user_role IN ('customer', 'vendor', 'delivery', 'admin')),
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    order_id UUID REFERENCES public.orders(id) ON DELETE CASCADE,
    type TEXT NOT NULL, -- e.g., 'ORDER_STATUS', 'CHAT_MESSAGE', 'PAYMENT_SUCCESS', 'SYSTEM'
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Realtime
ALTER TABLE public.notifications REPLICA IDENTITY FULL;
-- Note: You must enable "Realtime" for this table in the Supabase Dashboard.

-- 2. Device Tokens Table (Robust Registration)
CREATE TABLE IF NOT EXISTS public.device_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    user_role TEXT NOT NULL, -- 'customer', 'vendor', 'delivery', 'admin'
    device_token TEXT NOT NULL,
    device_type TEXT DEFAULT 'android',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, device_token)
);

-- 3. Trigger Function: Order Status Notifications
CREATE OR REPLACE FUNCTION public.fn_notify_order_change()
RETURNS TRIGGER AS $$
DECLARE
    v_customer_id UUID;
    v_vendor_id UUID;
    v_rider_id UUID;
    v_shop_name TEXT;
    v_customer_name TEXT;
BEGIN
    -- Get involved IDs
    v_customer_id := NEW.customer_id;
    v_vendor_id := NEW.vendor_id;
    v_rider_id := NEW.delivery_partner_id;

    -- Get Shop Name
    SELECT shop_name INTO v_shop_name FROM public.vendors WHERE id = v_vendor_id;
    -- Get Customer Name
    SELECT full_name INTO v_customer_name FROM public.customer_profiles WHERE id = v_customer_id;

    -- NO-OP if status hasn't changed (unless it's a new order)
    IF (TG_OP = 'UPDATE' AND OLD.order_status = NEW.order_status) THEN
        RETURN NEW;
    END IF;

    -- CASE: Order Placed -> Notify Vendor
    IF NEW.order_status = 'placed' THEN
        INSERT INTO public.notifications (user_id, user_role, title, message, order_id, type)
        VALUES (v_vendor_id::TEXT, 'vendor', 'New Order Received! 🍛', 'You have a new order from ' || COALESCE(v_customer_name, 'Guest') || '.', NEW.id, 'ORDER_STATUS');
    END IF;

    -- CASE: Vendor Accepted -> Notify Customer
    IF NEW.order_status = 'accepted' OR NEW.order_status = 'confirmed' THEN
        INSERT INTO public.notifications (user_id, user_role, title, message, order_id, type)
        VALUES (v_customer_id::TEXT, 'customer', 'Order Accepted! ✅', v_shop_name || ' is preparing your food.', NEW.id, 'ORDER_STATUS');
    END IF;

    -- CASE: Rider Assigned -> Notify Customer, Vendor & Rider
    IF NEW.order_status = 'assigned' OR (OLD.delivery_partner_id IS NULL AND NEW.delivery_partner_id IS NOT NULL) THEN
        INSERT INTO public.notifications (user_id, user_role, title, message, order_id, type)
        VALUES (v_customer_id::TEXT, 'customer', 'Rider Assigned 🏍️', 'Your delivery partner is on the way.', NEW.id, 'ORDER_STATUS');
        
        INSERT INTO public.notifications (user_id, user_role, title, message, order_id, type)
        VALUES (v_vendor_id::TEXT, 'vendor', 'Rider Assigned', 'A rider has been assigned for order #' || NEW.id, NEW.id, 'ORDER_STATUS');

        IF v_rider_id IS NOT NULL THEN
            INSERT INTO public.notifications (user_id, user_role, title, message, order_id, type)
            VALUES (v_rider_id::TEXT, 'delivery', 'New Assignment 🍔', 'You have been assigned to order #' || NEW.id, NEW.id, 'ORDER_STATUS');
        END IF;
    END IF;

    -- CASE: Order Picked Up -> Notify Customer
    IF NEW.order_status = 'picked_up' OR NEW.order_status = 'dispatched' THEN
        INSERT INTO public.notifications (user_id, user_role, title, message, order_id, type)
        VALUES (v_customer_id::TEXT, 'customer', 'Order Dispatched! 🚗', 'Your food has left the kitchen.', NEW.id, 'ORDER_STATUS');
    END IF;

    -- CASE: Order Delivered -> Notify All
    IF NEW.order_status = 'delivered' OR NEW.order_status = 'completed' THEN
        INSERT INTO public.notifications (user_id, user_role, title, message, order_id, type)
        VALUES (v_customer_id::TEXT, 'customer', 'Enjoy your meal! 🍛', 'Your order has been delivered successfully.', NEW.id, 'ORDER_STATUS');
        
        INSERT INTO public.notifications (user_id, user_role, title, message, order_id, type)
        VALUES (v_vendor_id::TEXT, 'vendor', 'Order Completed', 'Order #' || NEW.id || ' has been delivered.', NEW.id, 'ORDER_STATUS');

        IF v_rider_id IS NOT NULL THEN
             INSERT INTO public.notifications (user_id, user_role, title, message, order_id, type)
             VALUES (v_rider_id::TEXT, 'delivery', 'Mission Completed 🏆', 'Order delivered. Wallet updated.', NEW.id, 'ORDER_STATUS');
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create Trigger on Orders
DROP TRIGGER IF EXISTS tr_order_notifications ON public.orders;
CREATE TRIGGER tr_order_notifications
AFTER INSERT OR UPDATE ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.fn_notify_order_change();


-- 4. Trigger Function: Chat Notifications
CREATE OR REPLACE FUNCTION public.fn_notify_chat_message()
RETURNS TRIGGER AS $$
DECLARE
    v_receiver_id TEXT;
    v_sender_role TEXT;
    v_target_app TEXT;
BEGIN
    v_receiver_id := NEW.receiver_id;
    v_sender_role := NEW.sender_role;

    -- Determine receiver role/app
    -- Logic: If sender is 'customer', receiver is 'vendor' or 'admin'
    -- If sender is 'vendor', receiver is 'customer'
    IF v_sender_role = 'customer' THEN
        v_target_app := 'vendor'; -- Defaulting to vendor for order chat
    ELSIF v_sender_role = 'vendor' THEN
        v_target_app := 'customer';
    ELSIF v_sender_role = 'admin' THEN
        v_target_app := 'customer'; -- Or vendor depending on context
    ELSE
        v_target_app := 'customer';
    END IF;

    IF v_receiver_id IS NOT NULL AND v_receiver_id <> 'GUEST_USER' THEN
        INSERT INTO public.notifications (user_id, user_role, title, message, order_id, type)
        VALUES (v_receiver_id, v_target_app, 'New Message 💬', LEFT(NEW.message, 50), NEW.order_id, 'CHAT_MESSAGE');
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for Chat Messages
DROP TRIGGER IF EXISTS tr_chat_notifications ON public.chat_messages;
CREATE TRIGGER tr_chat_notifications
AFTER INSERT ON public.chat_messages
FOR EACH ROW EXECUTE FUNCTION public.fn_notify_chat_message();

-- 5. Support Message Notifications
CREATE OR REPLACE FUNCTION public.fn_notify_support_message()
RETURNS TRIGGER AS $$
BEGIN
    -- If admin sends message, notify user
    IF NEW.sender_role = 'admin' THEN
        INSERT INTO public.notifications (user_id, user_role, title, message, type)
        VALUES (NEW.sender_id, 'customer', 'Support Response 🤖', LEFT(NEW.message, 50), 'CHAT_MESSAGE');
    END IF;
    
    -- If user sends message, notify admins (broadcast to all admin roles in notification table or handle via dashboard)
    IF NEW.sender_role = 'customer' THEN
        INSERT INTO public.notifications (user_id, user_role, title, message, type)
        VALUES ('SYSTEM_ADMIN', 'admin', 'New Support Ticket', LEFT(NEW.message, 50), 'CHAT_MESSAGE');
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_support_notifications ON public.support_messages;
CREATE TRIGGER tr_support_notifications
AFTER INSERT ON public.support_messages
FOR EACH ROW EXECUTE FUNCTION public.fn_notify_support_message();

-- 6. RPC to clean old notifications
CREATE OR REPLACE FUNCTION public.clean_old_notifications()
RETURNS void AS $$
BEGIN
    DELETE FROM public.notifications WHERE created_at < NOW() - INTERVAL '30 days';
END;
$$ LANGUAGE plpgsql;
