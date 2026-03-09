-- 🚨 EMERGENCY LOGISTICS RECOVERY v61
-- 1. Fix user_id column type to TEXT (Supports Firebase UIDs)
-- 2. Remove dangerous ::uuid casts from triggers
-- 3. Fix real-time publication for notifications

BEGIN;

-- A. INFRASTRUCTURE REPAIR
DO $$ 
BEGIN
    -- 1. Notifications table sync
    ALTER TABLE public.notifications ALTER COLUMN user_id TYPE TEXT;
    ALTER TABLE public.notifications ALTER COLUMN order_id TYPE TEXT;
    
    -- 2. Orders table sync
    ALTER TABLE public.orders ALTER COLUMN customer_id TYPE TEXT;
    ALTER TABLE public.orders ALTER COLUMN status TYPE TEXT;
END $$;

-- B. REPAIR TRIGGER FUNCTION (NO UUID CASTS)
CREATE OR REPLACE FUNCTION handle_core_notifications_v4()
RETURNS TRIGGER AS $$
DECLARE
    v_customer_id text;
    v_order_short_id text;
BEGIN
    v_order_short_id := SUBSTRING(NEW.id::text, 1, 8);
    v_customer_id := NEW.customer_id::text;

    IF (TG_OP = 'UPDATE') THEN
        IF (UPPER(COALESCE(NEW.status, '')) != UPPER(COALESCE(OLD.status, ''))) THEN
            CASE UPPER(NEW.status)
                WHEN 'ACCEPTED' THEN
                    INSERT INTO public.notifications (user_id, title, message, order_id, type, event_type, role)
                    VALUES (v_customer_id, 'Order Accepted 👨‍🍳', 'The restaurant has started preparing your order.', NEW.id::text, 'order', 'ORDER_ACCEPTED', 'CUSTOMER');
                WHEN 'PREPARING' THEN
                    INSERT INTO public.notifications (user_id, title, message, order_id, type, event_type, role)
                    VALUES (v_customer_id, 'Preparing Your Food', 'Your delicious meal is being prepared.', NEW.id::text, 'order', 'PREPARING', 'CUSTOMER');
                WHEN 'READY' THEN
                    INSERT INTO public.notifications (user_id, title, message, order_id, type, event_type, role)
                    VALUES (v_customer_id, 'Ready for Extraction', 'Rider is arriving to pick up your order.', NEW.id::text, 'order', 'READY', 'CUSTOMER');
                WHEN 'PICKED_UP', 'ON_THE_WAY', 'TRANSIT' THEN
                    INSERT INTO public.notifications (user_id, title, message, order_id, type, event_type, role)
                    VALUES (v_customer_id, 'Out for Delivery 🚴', 'Your order is on the way!', NEW.id::text, 'order', 'IN_TRANSIT', 'CUSTOMER');
                WHEN 'DELIVERED' THEN
                    INSERT INTO public.notifications (user_id, title, message, order_id, type, event_type, role)
                    VALUES (v_customer_id, 'Delivered 🎉', 'Enjoy your meal! ⭐', NEW.id::text, 'order', 'DELIVERED', 'CUSTOMER');
                WHEN 'CANCELLED' THEN
                    INSERT INTO public.notifications (user_id, title, message, order_id, type, event_type, role)
                    VALUES (v_customer_id, 'Order Cancelled', 'Your order was cancelled. Refund initiated if applicable.', NEW.id::text, 'order', 'ORDER_CANCELLED', 'CUSTOMER');
                ELSE
                    -- Ignore other states
            END CASE;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- C. ATTACH TRIGGER
DROP TRIGGER IF EXISTS tr_core_notifications_v4 ON public.orders;
CREATE TRIGGER tr_core_notifications_v4
AFTER UPDATE ON public.orders
FOR EACH ROW EXECUTE FUNCTION handle_core_notifications_v4();

-- D. REPAIR REALTIME PUBLICATION
DO $$
BEGIN
    -- Ensure publication exists
    IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        CREATE PUBLICATION supabase_realtime;
    END IF;

    -- Add notifications to publication if not all tables
    IF (SELECT puballtables FROM pg_publication WHERE pubname = 'supabase_realtime') = false THEN
        IF NOT EXISTS (
            SELECT 1 FROM pg_publication_tables 
            WHERE pubname = 'supabase_realtime' 
            AND schemaname = 'public' 
            AND tablename = 'notifications'
        ) THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
        END IF;
    END IF;
END $$;

-- E. CLEAN UP OLD TRIGGERS that might be crashing
DROP TRIGGER IF EXISTS tr_ultimate_notifications ON public.orders;
DROP TRIGGER IF EXISTS tr_core_notifications_v3 ON public.orders;

COMMIT;

SELECT 'LOGISTICS RECOVERY COMPLETE' as status;
