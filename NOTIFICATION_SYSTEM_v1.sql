-- 🔔 MASTER REALTIME NOTIFICATION SYSTEM (Backend Engine)
-- Role-based, Event-driven, and Real-time synced.

BEGIN;

-- 1. NOTIFICATIONS TABLE
CREATE TABLE IF NOT EXISTS public.notifications (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id text NOT NULL, -- UUID as text for cross-platform compatibility
    role text NOT NULL, -- 'CUSTOMER', 'VENDOR', 'RIDER', 'ADMIN'
    title text NOT NULL,
    message text NOT NULL,
    event_type text NOT NULL, -- e.g., 'ORDER_PLACED'
    order_id uuid REFERENCES public.orders(id) ON DELETE CASCADE,
    is_read boolean DEFAULT false,
    created_at timestamptz DEFAULT now(),
    meta_data jsonb DEFAULT '{}'::jsonb
);

-- 2. ENSURE ALL ROLES HAVE FCM_TOKEN
ALTER TABLE public.customer_profiles ADD COLUMN IF NOT EXISTS fcm_token text;
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS fcm_token text;
ALTER TABLE public.delivery_riders ADD COLUMN IF NOT EXISTS fcm_token text;

-- 3. ENABLE REALTIME
ALTER TABLE public.notifications REPLICA IDENTITY FULL;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'notifications') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
    END IF;
END $$;

-- 4. HELPER FUNCTION: SEND NOTIFICATION (Internal)
CREATE OR REPLACE FUNCTION public.send_notification_v1(
    p_user_id text,
    p_role text,
    p_title text,
    p_message text,
    p_event text,
    p_order_id uuid DEFAULT NULL,
    p_meta jsonb DEFAULT '{}'::jsonb
)
RETURNS void AS $$
BEGIN
    INSERT INTO public.notifications (user_id, role, title, message, event_type, order_id, meta_data)
    VALUES (p_user_id, p_role, p_title, p_message, p_event, p_order_id, p_meta);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. MASTER TRIGGER: ORDER STATUS UPDATES
CREATE OR REPLACE FUNCTION public.trg_fn_order_notifications()
RETURNS TRIGGER AS $$
DECLARE
    v_vendor_owner_id text;
    v_rider_id text;
    v_customer_id text;
    v_vendor_name text;
BEGIN
    -- Prefetch IDs
    SELECT owner_id::text, name INTO v_vendor_owner_id, v_vendor_name FROM public.vendors WHERE id::text = NEW.vendor_id::text;
    v_rider_id := NEW.rider_id::text;
    v_customer_id := NEW.customer_id::text;

    -- CASE: Status Changes
    IF (OLD.status IS NULL OR OLD.status != NEW.status) THEN
        
        -- A. ORDER_PLACED (New Order)
        IF NEW.status = 'PENDING' OR NEW.status = 'pending' THEN
            PERFORM send_notification_v1(v_vendor_owner_id, 'VENDOR', 'New Order! 🍟', 'You have a new order to accept.', 'ORDER_PLACED', NEW.id);
        END IF;

        -- B. ORDER_ACCEPTED
        IF NEW.status IN ('ACCEPTED', 'accepted', 'PREPARING', 'preparing') AND (OLD.status NOT IN ('ACCEPTED', 'accepted', 'PREPARING', 'preparing')) THEN
            PERFORM send_notification_v1(v_customer_id, 'CUSTOMER', 'Order Accepted! ✅', v_vendor_name || ' is now preparing your meal.', 'ORDER_ACCEPTED', NEW.id);
        END IF;

        -- C. ORDER_READY
        IF NEW.status IN ('READY', 'ready') AND (OLD.status != 'READY') THEN
            PERFORM send_notification_v1(v_customer_id, 'CUSTOMER', 'Meal is Ready! 🥘', 'Rider is arriving to pick up your order.', 'ORDER_READY', NEW.id);
            -- Also notify available riders? (Usually handled by dispatch logic, but let's notify the assigned one if any)
            IF v_rider_id IS NOT NULL THEN
                PERFORM send_notification_v1(v_rider_id, 'RIDER', 'Pickup Ready! 📦', 'Head to ' || v_vendor_name || ' to pick up the order.', 'ORDER_READY', NEW.id);
            END IF;
        END IF;

        -- D. ORDER_PICKED_UP (Rider assigned or started on_the_way)
        IF NEW.status IN ('PICKED_UP', 'picked_up', 'on_the_way', 'ON_THE_WAY') AND (OLD.status NOT IN ('PICKED_UP', 'picked_up', 'on_the_way', 'ON_THE_WAY')) THEN
             PERFORM send_notification_v1(v_customer_id, 'CUSTOMER', 'Order Picked Up! 🛵', 'Your rider is on the way to your location.', 'ORDER_PICKED_UP', NEW.id);
        END IF;

        -- E. ORDER_DELIVERED
        IF NEW.status IN ('DELIVERED', 'delivered') AND (OLD.status != 'DELIVERED') THEN
            PERFORM send_notification_v1(v_customer_id, 'CUSTOMER', 'Enjoy your meal! 🍛', 'Order delivered successfully.', 'ORDER_DELIVERED', NEW.id);
            PERFORM send_notification_v1(v_vendor_owner_id, 'VENDOR', 'Order Delivered! 💰', 'Mission completed and settlement updated.', 'ORDER_DELIVERED', NEW.id);
        END IF;

        -- F. ORDER_CANCELLED
        IF NEW.status IN ('CANCELLED', 'cancelled') AND (OLD.status != 'CANCELLED') THEN
            PERFORM send_notification_v1(v_customer_id, 'CUSTOMER', 'Order Cancelled ❌', 'Your order was unfortunately cancelled.', 'ORDER_CANCELLED', NEW.id);
            PERFORM send_notification_v1(v_vendor_owner_id, 'VENDOR', 'Order Cancelled ❌', 'Order #' || NEW.id || ' has been cancelled.', 'ORDER_CANCELLED', NEW.id);
        END IF;

    END IF;

    -- CASE: Rider Assignment (If rider_id was null and is now set)
    IF (OLD.rider_id IS NULL AND NEW.rider_id IS NOT NULL) THEN
        PERFORM send_notification_v1(v_customer_id, 'CUSTOMER', 'Rider Assigned! 🛵', 'A delivery partner has been assigned to your order.', 'ORDER_RIDER_ASSIGNED', NEW.id);
        PERFORM send_notification_v1(NEW.rider_id::text, 'RIDER', 'New Mission! 🏁', 'You have been assigned to an order from ' || v_vendor_name, 'ORDER_RIDER_ASSIGNED', NEW.id);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_order_notifications_v1 ON public.orders;
CREATE TRIGGER trg_order_notifications_v1
AFTER INSERT OR UPDATE ON public.orders
FOR EACH ROW
EXECUTE FUNCTION public.trg_fn_order_notifications();

-- 6. ADMIN BROADCAST RPC
CREATE OR REPLACE FUNCTION public.admin_broadcast_notification(
    p_title text,
    p_message text,
    p_role text DEFAULT 'ALL', -- 'CUSTOMER', 'VENDOR', 'RIDER', 'ADMIN', 'ALL'
    p_target_id text DEFAULT NULL -- Optional specific user
)
RETURNS void AS $$
BEGIN
    IF p_target_id IS NOT NULL THEN
        PERFORM send_notification_v1(p_target_id, p_role, p_title, p_message, 'ADMIN_PUSH');
    ELSIF p_role = 'ALL' THEN
        -- Broadcast to everyone (This is expensive but okay for rare global alerts)
        INSERT INTO public.notifications (user_id, role, title, message, event_type)
        SELECT id::text, 'CUSTOMER', p_title, p_message, 'ADMIN_PUSH' FROM public.customer_profiles
        UNION ALL
        SELECT owner_id::text, 'VENDOR', p_title, p_message, 'ADMIN_PUSH' FROM public.vendors
        UNION ALL
        SELECT id::text, 'RIDER', p_title, p_message, 'ADMIN_PUSH' FROM public.delivery_riders;
    ELSE
        -- Broadcast to specific role
        IF p_role = 'CUSTOMER' THEN
            INSERT INTO public.notifications (user_id, role, title, message, event_type)
            SELECT id::text, 'CUSTOMER', p_title, p_message, 'ADMIN_PUSH' FROM public.customer_profiles;
        ELSIF p_role = 'VENDOR' THEN
            INSERT INTO public.notifications (user_id, role, title, message, event_type)
            SELECT owner_id::text, 'VENDOR', p_title, p_message, 'ADMIN_PUSH' FROM public.vendors;
        ELSIF p_role = 'RIDER' THEN
            INSERT INTO public.notifications (user_id, role, title, message, event_type)
            SELECT id::text, 'RIDER', p_title, p_message, 'ADMIN_PUSH' FROM public.delivery_riders;
        END IF;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. PERMISSIONS
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own notifications" ON public.notifications;
CREATE POLICY "Users can view their own notifications"
ON public.notifications
FOR SELECT
USING (user_id = auth.uid()::text);

DROP POLICY IF EXISTS "Users can update their own notifications" ON public.notifications;
CREATE POLICY "Users can update their own notifications"
ON public.notifications
FOR UPDATE
USING (user_id = auth.uid()::text);

-- ALLOW ADMIN TO SEE ALL (assuming admin role or specific UID check if needed)
CREATE POLICY "Admin can see all notifications"
ON public.notifications
FOR ALL
USING (true); -- Simplified for development, usually checks auth.jwt()->>'role' = 'admin'

GRANT ALL ON TABLE public.notifications TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_broadcast_notification TO authenticated, service_role;

COMMIT;
