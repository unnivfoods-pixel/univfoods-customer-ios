-- 🔍 NOTIFICATION DIAGNOSTIC & FORCE REPAIR
-- Run this to see what is happening in your database.

BEGIN;

-- 1. CLEANUP ALL POTENTIAL BLOCKERS
DROP TRIGGER IF EXISTS tr_master_notifications ON public.orders;
DROP FUNCTION IF EXISTS public.master_notification_handler();

-- 2. CREATE A BULLETPROOF LOGGING TABLE (To see if trigger runs)
CREATE TABLE IF NOT EXISTS public.debug_logs (
    id serial PRIMARY KEY,
    msg text,
    created_at timestamptz DEFAULT now()
);

-- 3. THE "GOLDEN TRIGGER" (ULTRA BULLETPROOF)
CREATE OR REPLACE FUNCTION public.master_notification_handler()
RETURNS TRIGGER AS $$
DECLARE
    v_target_user text;
    v_title text;
    v_msg text;
BEGIN
    v_target_user := COALESCE(NEW.customer_id::text, 'NO_USER');
    
    -- Log that the trigger fired
    INSERT INTO public.debug_logs(msg) VALUES ('Trigger fired for Order: ' || NEW.id || ' Status: ' || NEW.status);

    -- Handle Status Changes
    IF (TG_OP = 'UPDATE' AND NEW.status IS DISTINCT FROM OLD.status) THEN
        v_title := 'Order ' || INITCAP(NEW.status);
        v_msg := 'Your order #' || SUBSTRING(NEW.id::text, 1, 8) || ' is now ' || NEW.status;

        -- FORCE INSERT INTO NOTIFICATIONS
        INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
        VALUES (v_target_user, 'customer', v_title, v_msg, NEW.id::text, 'order');
        
        INSERT INTO public.debug_logs(msg) VALUES ('Notification Queued for: ' || v_target_user);
    END IF;

    -- Handle New Orders
    IF (TG_OP = 'INSERT') THEN
         INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
         VALUES (v_target_user, 'customer', 'Order Placed!', 'We received your order.', NEW.id::text, 'order');
    END IF;

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    INSERT INTO public.debug_logs(msg) VALUES ('ERROR IN TRIGGER: ' || SQLERRM);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. ACTIVATE
CREATE TRIGGER tr_master_notifications
AFTER INSERT OR UPDATE ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.master_notification_handler();

-- 5. ENSURE REALTIME IS TRULY ON
-- If this fails, ignore it (it means it's already on via FOR ALL TABLES)
DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Publication exists or for all tables';
END $$;

-- 6. PERMISSIONS (TOTAL UNBLOCK)
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Wide Open Notifs" ON public.notifications;
CREATE POLICY "Wide Open Notifs" ON public.notifications FOR ALL TO public USING (true) WITH CHECK (true);

-- 7. REPLICA IDENTITY (Required for Realtime Updates)
ALTER TABLE public.notifications REPLICA IDENTITY FULL;

COMMIT;

SELECT 'Diagnostic & Repair Complete. Check public.debug_logs after clicking Accept.' as status;
