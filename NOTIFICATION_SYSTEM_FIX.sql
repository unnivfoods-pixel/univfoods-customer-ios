-- 🔥 NOTIFICATION SYSTEM FIX
-- This creates database triggers to send notifications automatically

-- 1. CREATE NOTIFICATIONS TABLE (if not exists)
CREATE TABLE IF NOT EXISTS public.notifications (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at timestamptz DEFAULT now(),
    user_id uuid,
    title text NOT NULL,
    body text NOT NULL,
    role text DEFAULT 'USER',
    is_read boolean DEFAULT false,
    order_id uuid REFERENCES public.orders(id) ON DELETE CASCADE,
    image_url text
);

-- 2. CREATE CAMPAIGNS TABLE (if not exists)
CREATE TABLE IF NOT EXISTS public.campaigns (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at timestamptz DEFAULT now(),
    title text NOT NULL,
    body text NOT NULL,
    image_url text,
    target_audience text DEFAULT 'ALL',
    status text DEFAULT 'draft',
    created_by uuid
);

-- 3. ADD FCM_TOKEN COLUMN TO CUSTOMER_PROFILES
ALTER TABLE public.customer_profiles 
ADD COLUMN IF NOT EXISTS fcm_token text;

-- 4. CREATE FUNCTION TO SEND NOTIFICATION ON NEW ORDER
CREATE OR REPLACE FUNCTION notify_new_order()
RETURNS TRIGGER AS $$
BEGIN
    -- Insert notification for customer
    INSERT INTO public.notifications (user_id, title, body, role, order_id)
    VALUES (
        NEW.customer_id,
        '🎉 Order Placed Successfully!',
        'Your order #' || SUBSTRING(NEW.id::text, 1, 8) || ' has been placed. Total: ₹' || NEW.total_amount,
        'ORDER',
        NEW.id
    );
    
    -- Insert notification for vendor
    INSERT INTO public.notifications (user_id, title, body, role, order_id)
    VALUES (
        NEW.vendor_id,
        '🔔 New Order Received!',
        'You have a new order #' || SUBSTRING(NEW.id::text, 1, 8) || ' worth ₹' || NEW.total_amount,
        'ORDER',
        NEW.id
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5. CREATE TRIGGER FOR NEW ORDERS
DROP TRIGGER IF EXISTS on_order_created ON public.orders;
CREATE TRIGGER on_order_created
    AFTER INSERT ON public.orders
    FOR EACH ROW
    EXECUTE FUNCTION notify_new_order();

-- 6. CREATE FUNCTION TO SEND NOTIFICATION ON ORDER STATUS CHANGE
CREATE OR REPLACE FUNCTION notify_order_status_change()
RETURNS TRIGGER AS $$
DECLARE
    status_message text;
BEGIN
    -- Only notify if status actually changed
    IF NEW.status != OLD.status THEN
        -- Set message based on status
        CASE NEW.status
            WHEN 'CONFIRMED' THEN
                status_message := '✅ Order Confirmed! Your order is being prepared.';
            WHEN 'PREPARING' THEN
                status_message := '👨‍🍳 Order is being prepared by the restaurant.';
            WHEN 'READY' THEN
                status_message := '📦 Order is ready for pickup!';
            WHEN 'PICKED_UP' THEN
                status_message := '🛵 Rider is on the way to deliver your order!';
            WHEN 'DELIVERED' THEN
                status_message := '🎉 Order delivered! Enjoy your meal!';
            WHEN 'CANCELLED' THEN
                status_message := '❌ Order has been cancelled.';
            ELSE
                status_message := 'Order status updated to: ' || NEW.status;
        END CASE;
        
        -- Insert notification
        INSERT INTO public.notifications (user_id, title, body, role, order_id)
        VALUES (
            NEW.customer_id,
            'Order Update #' || SUBSTRING(NEW.id::text, 1, 8),
            status_message,
            'ORDER',
            NEW.id
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 7. CREATE TRIGGER FOR ORDER STATUS CHANGES
DROP TRIGGER IF EXISTS on_order_status_changed ON public.orders;
CREATE TRIGGER on_order_status_changed
    AFTER UPDATE ON public.orders
    FOR EACH ROW
    EXECUTE FUNCTION notify_order_status_change();

-- 8. ENABLE REALTIME FOR NOTIFICATIONS
ALTER TABLE public.notifications REPLICA IDENTITY FULL;

-- 9. ADD TO REALTIME PUBLICATION
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR TABLE 
    public.orders, 
    public.delivery_riders, 
    public.vendors, 
    public.customer_profiles,
    public.notifications,
    public.products,
    public.categories;

-- 10. ALLOW ALL ACCESS TO NOTIFICATIONS (TEMPORARY)
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all access" ON public.notifications;
CREATE POLICY "Allow all access" ON public.notifications FOR ALL USING (true) WITH CHECK (true);

-- ✅ DONE! Now notifications will be sent automatically when:
-- 1. New order is placed
-- 2. Order status changes
-- 3. Admin sends campaign from admin panel
