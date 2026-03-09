-- 🔔 COMPLETE NOTIFICATION SYSTEM - ALL APPS
-- Customer App · Vendor App · Delivery Partner App
-- Implements ALL notification scenarios with priority levels

-- ============================================
-- 1. ENSURE TABLES EXIST
-- ============================================

-- Notifications table
CREATE TABLE IF NOT EXISTS public.notifications (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at timestamptz DEFAULT now(),
    user_id uuid,
    title text NOT NULL,
    body text NOT NULL,
    role text DEFAULT 'CUSTOMER', -- CUSTOMER, VENDOR, RIDER, ADMIN
    priority text DEFAULT 'NORMAL', -- NORMAL, HIGH
    is_read boolean DEFAULT false,
    order_id uuid REFERENCES public.orders(id) ON DELETE CASCADE,
    image_url text,
    deep_link text, -- Screen to navigate to
    data jsonb -- Extra data for deep linking
);

-- FCM tokens in all profile tables
ALTER TABLE public.customer_profiles ADD COLUMN IF NOT EXISTS fcm_token text;
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS fcm_token text;
ALTER TABLE public.delivery_riders ADD COLUMN IF NOT EXISTS fcm_token text;

-- ============================================
-- 2. ORDER LIFECYCLE NOTIFICATIONS
-- ============================================

-- 🛒 NEW ORDER PLACED
CREATE OR REPLACE FUNCTION notify_order_placed()
RETURNS TRIGGER AS $$
BEGIN
    -- Customer notification
    INSERT INTO public.notifications (user_id, title, body, role, priority, order_id, deep_link)
    VALUES (
        NEW.customer_id,
        '🎉 Order Placed Successfully!',
        'Your order #' || SUBSTRING(NEW.id::text, 1, 8) || ' has been placed successfully. Total: ₹' || NEW.total_amount,
        'CUSTOMER',
        'NORMAL',
        NEW.id,
        '/orders/' || NEW.id
    );
    
    -- Vendor notification (HIGH PRIORITY)
    INSERT INTO public.notifications (user_id, title, body, role, priority, order_id, deep_link)
    VALUES (
        NEW.vendor_id,
        '🔔 New Order Received!',
        'New order #' || SUBSTRING(NEW.id::text, 1, 8) || ' received. Amount: ₹' || NEW.total_amount,
        'VENDOR',
        'HIGH',
        NEW.id,
        '/orders/' || NEW.id
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_order_placed ON public.orders;
CREATE TRIGGER on_order_placed
    AFTER INSERT ON public.orders
    FOR EACH ROW
    EXECUTE FUNCTION notify_order_placed();

-- 📝 ORDER STATUS CHANGES
CREATE OR REPLACE FUNCTION notify_order_status()
RETURNS TRIGGER AS $$
DECLARE
    customer_title text;
    customer_body text;
    vendor_title text;
    vendor_body text;
    rider_title text;
    rider_body text;
    vendor_name text;
    rider_name text;
BEGIN
    -- Only if status changed
    IF NEW.status = OLD.status THEN
        RETURN NEW;
    END IF;
    
    -- Get vendor name
    SELECT name INTO vendor_name FROM public.vendors WHERE id = NEW.vendor_id LIMIT 1;
    
    -- Get rider name
    IF NEW.delivery_partner_id IS NOT NULL THEN
        SELECT name INTO rider_name FROM public.delivery_riders WHERE id = NEW.delivery_partner_id LIMIT 1;
    END IF;
    
    -- Set messages based on status
    CASE NEW.status
        WHEN 'CONFIRMED' THEN
            customer_title := '✅ Order Accepted';
            customer_body := COALESCE(vendor_name, 'Restaurant') || ' has accepted your order.';
            
        WHEN 'PREPARING' THEN
            customer_title := '👨‍🍳 Food Being Prepared';
            customer_body := 'Your food is being prepared.';
            vendor_title := '👨‍🍳 Order Preparing';
            vendor_body := 'Order #' || SUBSTRING(NEW.id::text, 1, 8) || ' is now being prepared.';
            
        WHEN 'READY' THEN
            customer_title := '📦 Order Ready!';
            customer_body := 'Your order is ready for pickup.';
            vendor_title := '📦 Order Ready';
            vendor_body := 'Order #' || SUBSTRING(NEW.id::text, 1, 8) || ' ready for pickup.';
            
        WHEN 'PICKED_UP' THEN
            customer_title := '🛵 Out for Delivery';
            customer_body := COALESCE(rider_name, 'Delivery partner') || ' is on the way with your order 🚴';
            vendor_title := '✅ Order Picked Up';
            vendor_body := 'Order #' || SUBSTRING(NEW.id::text, 1, 8) || ' picked up.';
            rider_title := '📦 Pickup Confirmed';
            rider_body := 'Pickup successful. Navigate to customer.';
            
        WHEN 'DELIVERED' THEN
            customer_title := '🎉 Order Delivered';
            customer_body := 'Order delivered. Enjoy your meal 😋';
            rider_title := '✅ Delivery Completed';
            rider_body := 'Order delivered successfully.';
            
        WHEN 'CANCELLED' THEN
            customer_title := '❌ Order Cancelled';
            customer_body := 'Your order has been cancelled. Refund in progress.';
            vendor_title := '❌ Order Cancelled';
            vendor_body := 'Order #' || SUBSTRING(NEW.id::text, 1, 8) || ' has been cancelled.';
            IF NEW.delivery_partner_id IS NOT NULL THEN
                rider_title := '❌ Order Cancelled';
                rider_body := 'Order cancelled before delivery.';
            END IF;
            
        ELSE
            customer_title := '📝 Order Update';
            customer_body := 'Order status: ' || NEW.status;
    END CASE;
    
    -- Send customer notification
    IF customer_title IS NOT NULL THEN
        INSERT INTO public.notifications (user_id, title, body, role, priority, order_id, deep_link)
        VALUES (NEW.customer_id, customer_title, customer_body, 'CUSTOMER', 'NORMAL', NEW.id, '/orders/' || NEW.id);
    END IF;
    
    -- Send vendor notification
    IF vendor_title IS NOT NULL THEN
        INSERT INTO public.notifications (user_id, title, body, role, priority, order_id, deep_link)
        VALUES (NEW.vendor_id, vendor_title, vendor_body, 'VENDOR', 'HIGH', NEW.id, '/orders/' || NEW.id);
    END IF;
    
    -- Send rider notification
    IF rider_title IS NOT NULL AND NEW.delivery_partner_id IS NOT NULL THEN
        INSERT INTO public.notifications (user_id, title, body, role, priority, order_id, deep_link)
        VALUES (NEW.delivery_partner_id, rider_title, rider_body, 'RIDER', 'HIGH', NEW.id, '/orders/' || NEW.id);
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_order_status_changed ON public.orders;
CREATE TRIGGER on_order_status_changed
    AFTER UPDATE ON public.orders
    FOR EACH ROW
    EXECUTE FUNCTION notify_order_status();

-- ============================================
-- 3. DELIVERY PARTNER ASSIGNMENT
-- ============================================

CREATE OR REPLACE FUNCTION notify_rider_assigned()
RETURNS TRIGGER AS $$
DECLARE
    rider_name text;
BEGIN
    -- Only if rider was just assigned
    IF NEW.delivery_partner_id IS NOT NULL AND 
       (OLD.delivery_partner_id IS NULL OR OLD.delivery_partner_id != NEW.delivery_partner_id) THEN
        
        -- Get rider name
        SELECT name INTO rider_name FROM public.delivery_riders WHERE id = NEW.delivery_partner_id LIMIT 1;
        
        -- Notify customer
        INSERT INTO public.notifications (user_id, title, body, role, priority, order_id, deep_link)
        VALUES (
            NEW.customer_id,
            '🛵 Delivery Partner Assigned',
            COALESCE(rider_name, 'A delivery partner') || ' has been assigned to your order.',
            'CUSTOMER',
            'NORMAL',
            NEW.id,
            '/track/' || NEW.id
        );
        
        -- Notify vendor
        INSERT INTO public.notifications (user_id, title, body, role, priority, order_id, deep_link)
        VALUES (
            NEW.vendor_id,
            '🛵 Delivery Partner Assigned',
            'Delivery partner assigned for order #' || SUBSTRING(NEW.id::text, 1, 8),
            'VENDOR',
            'NORMAL',
            NEW.id,
            '/orders/' || NEW.id
        );
        
        -- Notify rider (HIGH PRIORITY)
        INSERT INTO public.notifications (user_id, title, body, role, priority, order_id, deep_link)
        VALUES (
            NEW.delivery_partner_id,
            '🛎️ New Delivery Assigned',
            'Order #' || SUBSTRING(NEW.id::text, 1, 8) || ' assigned to you. Navigate to restaurant.',
            'RIDER',
            'HIGH',
            NEW.id,
            '/deliveries/' || NEW.id
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_rider_assigned ON public.orders;
CREATE TRIGGER on_rider_assigned
    AFTER UPDATE ON public.orders
    FOR EACH ROW
    EXECUTE FUNCTION notify_rider_assigned();

-- ============================================
-- 4. PAYMENT NOTIFICATIONS
-- ============================================

CREATE OR REPLACE FUNCTION notify_payment_success()
RETURNS TRIGGER AS $$
BEGIN
    -- Only if payment status changed to success
    IF NEW.payment_status = 'PAID' AND (OLD.payment_status IS NULL OR OLD.payment_status != 'PAID') THEN
        
        -- Notify customer
        INSERT INTO public.notifications (user_id, title, body, role, priority, order_id, deep_link)
        VALUES (
            NEW.customer_id,
            '💰 Payment Successful',
            'Payment successful for order #' || SUBSTRING(NEW.id::text, 1, 8) || '. Amount: ₹' || NEW.total_amount,
            'CUSTOMER',
            'NORMAL',
            NEW.id,
            '/orders/' || NEW.id
        );
        
        -- Notify vendor
        INSERT INTO public.notifications (user_id, title, body, role, priority, order_id, deep_link)
        VALUES (
            NEW.vendor_id,
            '💰 Online Payment Received',
            'Payment received for order #' || SUBSTRING(NEW.id::text, 1, 8) || '. Amount: ₹' || NEW.total_amount,
            'VENDOR',
            'NORMAL',
            NEW.id,
            '/orders/' || NEW.id
        );
    END IF;
    
    -- COD notification
    IF NEW.payment_method = 'COD' AND NEW.status = 'CONFIRMED' THEN
        -- Notify rider when assigned
        IF NEW.delivery_partner_id IS NOT NULL THEN
            INSERT INTO public.notifications (user_id, title, body, role, priority, order_id, deep_link)
            VALUES (
                NEW.delivery_partner_id,
                '💵 COD Collection',
                'Collect ₹' || NEW.total_amount || ' from customer.',
                'RIDER',
                'HIGH',
                NEW.id,
                '/deliveries/' || NEW.id
            );
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_payment_status_changed ON public.orders;
CREATE TRIGGER on_payment_status_changed
    AFTER UPDATE ON public.orders
    FOR EACH ROW
    EXECUTE FUNCTION notify_payment_success();

-- ============================================
-- 5. ENABLE REALTIME
-- ============================================

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications REPLICA IDENTITY FULL;

-- Allow all access (temporary - refine later)
DROP POLICY IF EXISTS "Allow all access" ON public.notifications;
CREATE POLICY "Allow all access" ON public.notifications FOR ALL USING (true) WITH CHECK (true);

-- Add to realtime publication
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR TABLE 
    public.orders, 
    public.delivery_riders, 
    public.vendors, 
    public.customer_profiles,
    public.notifications,
    public.products,
    public.categories;

-- ============================================
-- 6. HELPER FUNCTION FOR ADMIN CAMPAIGNS
-- ============================================

CREATE OR REPLACE FUNCTION send_campaign(
    p_title text,
    p_body text,
    p_target_role text DEFAULT 'CUSTOMER',
    p_image_url text DEFAULT NULL
)
RETURNS integer AS $$
DECLARE
    notification_count integer := 0;
BEGIN
    -- Send to customers
    IF p_target_role = 'CUSTOMER' OR p_target_role = 'ALL' THEN
        WITH inserted AS (
            INSERT INTO public.notifications (user_id, title, body, role, priority, image_url)
            SELECT id, p_title, p_body, 'CUSTOMER', 'NORMAL', p_image_url
            FROM public.customer_profiles
            LIMIT 1000
            RETURNING 1
        )
        SELECT COUNT(*) INTO notification_count FROM inserted;
    END IF;
    
    -- Send to vendors
    IF p_target_role = 'VENDOR' OR p_target_role = 'ALL' THEN
        WITH inserted AS (
            INSERT INTO public.notifications (user_id, title, body, role, priority, image_url)
            SELECT id, p_title, p_body, 'VENDOR', 'NORMAL', p_image_url
            FROM public.vendors
            LIMIT 1000
            RETURNING 1
        )
        SELECT notification_count + COUNT(*) INTO notification_count FROM inserted;
    END IF;
    
    -- Send to riders
    IF p_target_role = 'RIDER' OR p_target_role = 'ALL' THEN
        WITH inserted AS (
            INSERT INTO public.notifications (user_id, title, body, role, priority, image_url)
            SELECT id, p_title, p_body, 'RIDER', 'NORMAL', p_image_url
            FROM public.delivery_riders
            LIMIT 1000
            RETURNING 1
        )
        SELECT notification_count + COUNT(*) INTO notification_count FROM inserted;
    END IF;
    
    RETURN notification_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- ✅ VERIFICATION
-- ============================================

SELECT 'Notification system installed successfully!' as status;

-- Test: Check if triggers exist
SELECT 
    trigger_name,
    event_object_table,
    action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'public'
AND event_object_table = 'orders'
ORDER BY trigger_name;
