-- 🚀 DAY 7: NOTIFICATION ENGINE (FINAL STABILIZATION)
-- Goal: Unified notification source of truth with calibrated field mapping.

BEGIN;

-- 0. Ensure Notifications Table exists with all stabilized columns
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    user_role TEXT NOT NULL, -- 'customer', 'vendor', 'delivery', 'admin'
    title TEXT,
    message TEXT,
    type TEXT DEFAULT 'ORDER_STATUS',
    order_id TEXT,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Add missing columns if table existed but was from an older version
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='notifications' AND column_name='user_role') THEN
        ALTER TABLE public.notifications ADD COLUMN user_role TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='notifications' AND column_name='type') THEN
        ALTER TABLE public.notifications ADD COLUMN type TEXT DEFAULT 'ORDER_STATUS';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='notifications' AND column_name='order_id') THEN
        ALTER TABLE public.notifications ADD COLUMN order_id TEXT;
    END IF;
END $$;

-- 1. Correct Trigger Function: Order Status Notifications
-- Mapping to standardized 'orders' table (rider_id, vendor_id, customer_id)
CREATE OR REPLACE FUNCTION public.fn_notify_order_change_v2()
RETURNS TRIGGER AS $$
DECLARE
    v_shop_name TEXT;
    v_customer_name TEXT;
BEGIN
    -- NO-OP if status hasn't changed (unless it's a new order)
    IF (TG_OP = 'UPDATE' AND OLD.order_status = NEW.order_status) THEN
        RETURN NEW;
    END IF;

    -- Get Shop Name for context (Resilient lookup)
    SELECT COALESCE(name, 'The Restaurant') INTO v_shop_name FROM public.vendors WHERE (id::text) = (NEW.vendor_id::text);
    -- Get Customer Name (Resilient lookup - using full_name which is the truth in V60)
    SELECT COALESCE(full_name, 'Customer') INTO v_customer_name FROM public.customer_profiles WHERE (id::text) = (NEW.customer_id::text);

    -- CASE: Order Placed -> Notify Vendor
    IF NEW.order_status = 'PLACED' THEN
        INSERT INTO public.notifications (user_id, user_role, title, message, order_id, type)
        VALUES (NEW.vendor_id::TEXT, 'vendor', 'New Order Received! 🍛', 'Order #' || LEFT(NEW.id::text, 8) || ' from ' || COALESCE(v_customer_name, 'Customer') || '.', NEW.id, 'ORDER_STATUS');
    END IF;

    -- CASE: Vendor Accepted -> Notify Customer
    IF NEW.order_status = 'ACCEPTED' THEN
        INSERT INTO public.notifications (user_id, user_role, title, message, order_id, type)
        VALUES (NEW.customer_id::TEXT, 'customer', 'Order Accepted! ✅', COALESCE(v_shop_name, 'The restaurant') || ' is now preparing your food.', NEW.id, 'ORDER_STATUS');
    END IF;

    -- CASE: Rider Assigned -> Notify Customer, Vendor & Rider
    IF NEW.order_status = 'RIDER_ASSIGNED' THEN
        INSERT INTO public.notifications (user_id, user_role, title, message, order_id, type)
        VALUES (NEW.customer_id::TEXT, 'customer', 'Rider Assigned 🏍️', 'Your delivery partner is on the way to the restaurant.', NEW.id, 'ORDER_STATUS');
        
        IF NEW.rider_id IS NOT NULL THEN
            INSERT INTO public.notifications (user_id, user_role, title, message, order_id, type)
            VALUES (NEW.rider_id::TEXT, 'delivery', 'New Mission Assigned!', 'Pick up from ' || COALESCE(v_shop_name, 'the restaurant') || '.', NEW.id, 'ORDER_STATUS');
        END IF;
    END IF;

    -- CASE: Order Picked Up -> Notify Customer
    IF NEW.order_status = 'PICKED_UP' THEN
        INSERT INTO public.notifications (user_id, user_role, title, message, order_id, type)
        VALUES (NEW.customer_id::TEXT, 'customer', 'Out for Delivery! 🚀', 'Your food has been picked up.', NEW.id, 'ORDER_STATUS');
    END IF;

    -- CASE: Order Delivered -> Notify All
    IF NEW.order_status = 'DELIVERED' THEN
        INSERT INTO public.notifications (user_id, user_role, title, message, order_id, type)
        VALUES (NEW.customer_id::TEXT, 'customer', 'Enjoy your meal! 🍛', 'Your order delivered successfully.', NEW.id, 'ORDER_STATUS');
        
        INSERT INTO public.notifications (user_id, user_role, title, message, order_id, type)
        VALUES (NEW.vendor_id::TEXT, 'vendor', 'Order Completed', 'Payment of ₹' || NEW.total_amount || ' credited to wallet.', NEW.id, 'ORDER_STATUS');

        IF NEW.rider_id IS NOT NULL THEN
             INSERT INTO public.notifications (user_id, user_role, title, message, order_id, type)
             VALUES (NEW.rider_id::TEXT, 'delivery', 'Earning Received 🏆', 'Fixed delivery fee added to your wallet.', NEW.id, 'ORDER_STATUS');
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Re-attach Trigger
DROP TRIGGER IF EXISTS tr_order_notifications ON public.orders;
CREATE TRIGGER tr_order_notifications
AFTER INSERT OR UPDATE ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.fn_notify_order_change_v2();

-- 2. Mark Notification as Read RPC
CREATE OR REPLACE FUNCTION public.mark_notification_read_v1(p_notification_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE public.notifications SET is_read = TRUE WHERE id = p_notification_id AND (user_id::text) = (auth.uid()::text);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. FINAL MASTER TRACKING VIEW (REALTIME + GIS)
-- This ensures all apps use the same view for order tracking and history.
DROP VIEW IF EXISTS public.order_tracking_stabilized_v1;
CREATE OR REPLACE VIEW public.order_tracking_stabilized_v1 AS
SELECT 
    o.id AS order_id, 
    o.id AS id, 
    o.customer_id, 
    o.vendor_id, 
    o.rider_id AS delivery_id,
    o.order_status, 
    o.order_status AS status,
    o.payment_status, 
    o.payment_status AS payment_state,
    o.total_amount,
    o.total_amount AS total,
    o.delivery_address,
    o.delivery_lat, 
    o.delivery_lng, 
    o.vendor_lat, 
    o.vendor_lng,
    o.rider_lat, 
    o.rider_lng, 
    o.delivered_at,
    o.created_at, 
    v.name AS vendor_name, 
    v.image_url AS vendor_image,
    COALESCE(v.banner_url, v.image_url) as vendor_banner,
    r.name AS rider_name, 
    r.phone AS rider_phone,
    u.full_name AS customer_name -- REPLACED u.name WITH u.full_name
FROM public.orders o
LEFT JOIN public.vendors v ON (o.vendor_id::text) = (v.id::text)
LEFT JOIN public.delivery_riders r ON (o.rider_id::text) = (r.id::text)
LEFT JOIN public.customer_profiles u ON (o.customer_id::text) = (u.id::text);

-- 4. REFRESH SCHEMA
NOTIFY pgrst, 'reload schema';

COMMIT;
