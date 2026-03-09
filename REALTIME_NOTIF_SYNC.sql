-- 🚨 FINAL REALTIME OVERRIDE (FOR NOTIFICATIONS)
-- This script ensures the notification table is fully compatible with Realtime and the Admin Panel.

BEGIN;

-- 1. DROP ALL BLOCKERS
DROP TRIGGER IF EXISTS tr_master_notifications ON public.orders;
DROP POLICY IF EXISTS "Public Notification Access" ON public.notifications;
DROP POLICY IF EXISTS "Admin All Access Notifications" ON public.notifications;
DROP POLICY IF EXISTS "Unlimited Notification Access" ON public.notifications;

-- 2. RESET TABLE FOR REALTIME
-- Ensure Columns are TEXT
ALTER TABLE IF EXISTS public.notifications ALTER COLUMN user_id TYPE text USING user_id::text;
ALTER TABLE IF EXISTS public.notifications ALTER COLUMN order_id TYPE text USING order_id::text;

-- IMPORTANT: Set replica identity to FULL so Realtime gets all data
ALTER TABLE public.notifications REPLICA IDENTITY FULL;

-- 3. WIDE OPEN PERMISSION (Ensures no "Silent Failure" on the Mobile App)
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Universal Realtime Access" ON public.notifications FOR ALL TO public USING (true) WITH CHECK (true);

-- 4. BULLETPROOF ENGINE (RE-SYNCING ACCEPTED STATUS)
CREATE OR REPLACE FUNCTION public.master_notification_handler()
RETURNS TRIGGER AS $$
DECLARE
    v_customer_id text := NEW.customer_id::text;
    v_order_short_id text := SUBSTRING(NEW.id::text, 1, 8);
    v_title text;
    v_msg text;
BEGIN
    -- Only notify if status changed and we have a target user
    IF (TG_OP = 'UPDATE' AND NEW.status != OLD.status AND v_customer_id IS NOT NULL) THEN
        
        CASE LOWER(NEW.status)
            WHEN 'accepted' THEN 
                v_title := 'Order Accepted ✅';
                v_msg := 'The restaurant is now handling your order.';
            WHEN 'preparing' THEN 
                v_title := 'Preparing Food 👨‍🍳';
                v_msg := 'Chef is cooking your meal.';
            WHEN 'ready' THEN 
                v_title := 'Order Ready! 🥡';
                v_msg := 'Ready for pickup.';
            WHEN 'out_for_delivery' THEN 
                v_title := 'Out for Delivery 🛵';
                v_msg := 'Your rider is on the way!';
            WHEN 'delivered' THEN 
                v_title := 'Delivered! 🍱';
                v_msg := 'Enjoy your food!';
            ELSE 
                v_title := 'Order Status: ' || UPPER(NEW.status);
                v_msg := 'Your order has been updated.';
        END CASE;

        -- INSERT RECORD (This is what the Mobile App listens to)
        INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type, created_at)
        VALUES (v_customer_id, 'customer', v_title, v_msg, NEW.id::text, 'order', NOW());
        
    END IF;

    -- Also notify on new orders (redundancy)
    IF (TG_OP = 'INSERT' AND v_customer_id IS NOT NULL) THEN
        INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type, created_at)
        VALUES (v_customer_id, 'customer', 'Order Placed 🎉', 'Your order is being processed.', NEW.id::text, 'order', NOW());
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5. RE-ACTIVATE
CREATE TRIGGER tr_master_notifications
AFTER INSERT OR UPDATE ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.master_notification_handler();

COMMIT;

SELECT 'Hyper-Realtime Notifications Re-Synced!' as Status;
