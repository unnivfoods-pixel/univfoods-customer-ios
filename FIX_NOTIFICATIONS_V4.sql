-- 🔔 NOTIFICATION SYSTEM V4 (STRING-ID ENHANCEMENT)
-- This script fixes the notification trigger and tables to handle the new TEXT/STRING ID format.

BEGIN;

-- 1. ALIGN NOTIFICATION TABLES WITH STRING IDs
ALTER TABLE IF EXISTS public.notifications ALTER COLUMN user_id TYPE text USING user_id::text;
ALTER TABLE IF EXISTS public.notifications ALTER COLUMN order_id TYPE text USING order_id::text;
ALTER TABLE IF EXISTS public.user_fcm_tokens ALTER COLUMN user_id TYPE text USING user_id::text;

-- 2. UPDATE THE MASTER TRIGGER TO HANDLE STRING IDs
CREATE OR REPLACE FUNCTION public.master_notification_handler()
RETURNS TRIGGER AS $$
DECLARE
    v_customer_id text; -- CHANGED: uuid -> text
    v_vendor_id text;   -- CHANGED: uuid -> text
    v_delivery_id text; -- CHANGED: uuid -> text
    v_admin_id text;    -- CHANGED: uuid -> text
    v_vendor_name text;
    v_rider_name text;
    v_order_short_id text;
    v_amount_fmt text;
BEGIN
    -- INIT
    v_order_short_id := SUBSTRING(NEW.id::text, 1, 8);
    v_customer_id := NEW.customer_id::text;
    v_vendor_id := NEW.vendor_id::text;
    
    -- Handle field naming variations (rider_id vs delivery_partner_id)
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='delivery_partner_id') THEN
        v_delivery_id := NEW.delivery_partner_id::text;
    ELSE
        v_delivery_id := NEW.rider_id::text;
    END IF;

    v_amount_fmt := COALESCE(NEW.total::text, '0.00');
    v_admin_id := '00000000-0000-0000-0000-000000000000'; 

    -- FETCH IDENTITY DATA
    SELECT name INTO v_vendor_name FROM public.vendors WHERE id::text = v_vendor_id;
    IF v_delivery_id IS NOT NULL THEN
        SELECT name INTO v_rider_name FROM public.delivery_riders WHERE id::text = v_delivery_id;
    END IF;

    -- 🛒 NEW ORDER PLACEMENT
    IF (TG_OP = 'INSERT') THEN
        -- Customer Confirmation
        INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
        VALUES (v_customer_id, 'customer', 'Order Confirmed 🎉', 'Your order #' || v_order_short_id || ' has been placed successfully.', NEW.id::text, 'order');
        
        -- Vendor Alert
        INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
        VALUES (v_vendor_id, 'vendor', 'New Order Received 🔔', 'Order #' || v_order_short_id || ' received. Accept soon!', NEW.id::text, 'order');
    END IF;

    -- 🔄 STATUS UPDATE
    IF (TG_OP = 'UPDATE') THEN
        IF (NEW.status != OLD.status) THEN
            CASE UPPER(NEW.status)
                WHEN 'PLACED' THEN
                     NULL; -- Already handled
                WHEN 'PREPARING', 'CONFIRMED' THEN
                    INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                    VALUES (v_customer_id, 'customer', 'Preparing Your Food', 'The restaurant is preparing your order.', NEW.id::text, 'order');
                WHEN 'READY' THEN
                    INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                    VALUES (v_customer_id, 'customer', 'Order Ready!', 'Your order is ready for pickup.', NEW.id::text, 'order');
                WHEN 'PICKED_UP', 'OUT_FOR_DELIVERY' THEN
                    INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                    VALUES (v_customer_id, 'customer', 'Out for Delivery', 'Your rider is on the way!', NEW.id::text, 'order');
                WHEN 'DELIVERED' THEN
                    INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                    VALUES (v_customer_id, 'customer', 'Delivered Successfully', 'Enjoy your meal! ⭐', NEW.id::text, 'order');
                WHEN 'CANCELLED' THEN
                    INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                    VALUES (v_customer_id, 'customer', 'Order Cancelled', 'Your order was cancelled.', NEW.id::text, 'order');
                ELSE
                    NULL;
            END CASE;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. RE-INSTALL TRIGGER
DROP TRIGGER IF EXISTS tr_master_notifications ON public.orders;
CREATE TRIGGER tr_master_notifications
AFTER INSERT OR UPDATE ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.master_notification_handler();

-- 4. FIX PUBLICATION (Graceful handling of "FOR ALL TABLES")
DO $$
BEGIN
    -- Check if publication exists but is NOT "FOR ALL TABLES"
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime' AND puballtables = false) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
    END IF;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Publication adjustment skipped: %', SQLERRM;
END $$;

COMMIT;

SELECT 'Notification System V4 (String-Compatible) installed!' as status;
