-- 🚀 THE ULTIMATE REALTIME RE-SYNC (v5.0)
-- Forces the database to talk to the phone instantly.

BEGIN;

-- 1. DROP BLOCKERS
DROP TRIGGER IF EXISTS tr_master_notifications ON public.orders;

-- 2. ENSURE NOTIFICATIONS TABLE IS FULLY REALTIME
-- This is critical: if replica identity is not FULL, some phones won't 'hear' it.
ALTER TABLE public.notifications REPLICA IDENTITY FULL;

-- 3. ENSURE ALL IDS ARE TEXT (Avoid string-vs-uuid conflict)
ALTER TABLE public.notifications ALTER COLUMN user_id TYPE text USING user_id::text;
ALTER TABLE public.notifications ALTER COLUMN order_id TYPE text USING order_id::text;

-- 4. THE PRO ENGINE (V5)
CREATE OR REPLACE FUNCTION public.master_notification_handler()
RETURNS TRIGGER AS $$
DECLARE
    v_c_id text := NEW.customer_id::text;
    v_s_id text := SUBSTRING(NEW.id::text, 1, 8);
    v_v_name text;
BEGIN
    -- Fetch Restaurant Name
    SELECT name INTO v_v_name FROM public.vendors WHERE id::text = NEW.vendor_id::text;
    v_v_name := COALESCE(v_v_name, 'The Restaurant');

    -- Only trigger on Status changes (to avoid spam)
    IF (TG_OP = 'UPDATE' AND NEW.status != OLD.status AND v_c_id IS NOT NULL) THEN
        INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
        VALUES (
            v_c_id, 
            'customer', 
            'Order Update: ' || UPPER(NEW.status), 
            'Your order #' || v_s_id || ' is now ' || NEW.status, 
            NEW.id::text, 
            'order'
        );
    END IF;

    -- Also on absolute new orders
    IF (TG_OP = 'INSERT' AND v_c_id IS NOT NULL) THEN
         INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
         VALUES (v_c_id, 'customer', '✅ Order Placed', 'Order #' || v_s_id || ' sent to ' || v_v_name, NEW.id::text, 'order');
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5. RE-ACTIVATE
CREATE TRIGGER tr_master_notifications AFTER INSERT OR UPDATE ON public.orders FOR EACH ROW EXECUTE FUNCTION public.master_notification_handler();

-- 6. ENABLE TABLE FOR REALTIME (Last attempt)
-- This ensures the table is actually in the 'realtime' publication list.
DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Skipping publication add (already added)';
END $$;

COMMIT;

SELECT 'Realtime Hyper-Sync v5.0 Complete!' as status;
