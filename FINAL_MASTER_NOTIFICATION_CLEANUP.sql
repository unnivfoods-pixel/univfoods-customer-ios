-- 🧹 FINAL MASTER NOTIFICATION CLEANUP & INSTALL (DEFINITIVE FIX)
-- This script removes all former notification triggers/functions to prevent DOUBLE NOTIFICATIONS.
-- It then installs the 100% Correct V3 Logic.

BEGIN;

-- ============================================
-- 1. CLEANUP ALL OLD ARTIFACTS
-- ============================================

-- Drop old triggers from public.orders
DROP TRIGGER IF EXISTS on_order_placed ON public.orders;
DROP TRIGGER IF EXISTS on_order_status_changed ON public.orders;
DROP TRIGGER IF EXISTS on_rider_assigned ON public.orders;
DROP TRIGGER IF EXISTS on_payment_status_changed ON public.orders;
DROP TRIGGER IF EXISTS on_order_status_update_notify ON public.orders;
DROP TRIGGER IF EXISTS tr_core_notifications ON public.orders;
DROP TRIGGER IF EXISTS tr_core_notifications_v2 ON public.orders;
DROP TRIGGER IF EXISTS tr_core_notifications_v3 ON public.orders;
DROP TRIGGER IF EXISTS "tr_master_notifications" ON "public"."orders";
DROP TRIGGER IF EXISTS "tr_master_notifications" ON "orders";

-- Drop old functions
DROP FUNCTION IF EXISTS notify_order_placed();
DROP FUNCTION IF EXISTS notify_order_status();
DROP FUNCTION IF EXISTS notify_rider_assigned();
DROP FUNCTION IF EXISTS notify_payment_success();
DROP FUNCTION IF EXISTS handle_core_notifications();
DROP FUNCTION IF EXISTS handle_core_notifications_v2();
DROP FUNCTION IF EXISTS handle_core_notifications_v3();

-- ============================================
-- 2. ENSURE UNIFIED SCHEMA
-- ============================================

CREATE TABLE IF NOT EXISTS public.notifications (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL,
    app_type text NOT NULL, -- customer / vendor / delivery / admin
    title text NOT NULL,
    message text NOT NULL,
    order_id uuid REFERENCES public.orders(id) ON DELETE CASCADE,
    type text NOT NULL, -- order / promo / alert / payout / refund
    read_status boolean DEFAULT false,
    created_at timestamptz DEFAULT now()
);

-- Central token store (Ensures no dupes across profile tables)
CREATE TABLE IF NOT EXISTS public.user_fcm_tokens (
    user_id uuid NOT NULL,
    app_type text NOT NULL,
    fcm_token text NOT NULL,
    updated_at timestamptz DEFAULT now(),
    PRIMARY KEY (user_id, app_type, fcm_token)
);

-- ============================================
-- 3. THE MASTER HYPER-REALTIME TRIGGER
-- ============================================

CREATE OR REPLACE FUNCTION public.master_notification_handler()
RETURNS TRIGGER AS $$
DECLARE
    v_customer_id uuid;
    v_vendor_id uuid;
    v_delivery_id uuid;
    v_admin_id uuid;
    v_vendor_name text;
    v_rider_name text;
    v_order_short_id text;
    v_amount_fmt text;
BEGIN
    -- INIT
    v_order_short_id := SUBSTRING(NEW.id::text, 1, 8);
    v_customer_id := NEW.customer_id::text::uuid;
    v_vendor_id := NEW.vendor_id::text::uuid;
    v_delivery_id := NEW.delivery_partner_id::text::uuid;
    v_amount_fmt := NEW.total_amount::text;
    
    v_admin_id := '00000000-0000-0000-0000-000000000000'::uuid; 

    -- FETCH IDENTITY DATA
    SELECT name INTO v_vendor_name FROM public.vendors WHERE id = v_vendor_id;
    IF v_delivery_id IS NOT NULL THEN
        SELECT name INTO v_rider_name FROM public.delivery_riders WHERE id = v_delivery_id;
    END IF;

    -- 🛒 NEW ORDER PLACEMENT
    IF (TG_OP = 'INSERT') THEN
        -- Customer Confirmation
        INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
        VALUES (v_customer_id, 'customer', 'Order Confirmed 🎉', 'Your order #' || v_order_short_id || ' has been placed successfully.', NEW.id, 'order');
        
        -- Vendor Alert
        INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
        VALUES (v_vendor_id, 'vendor', 'New Order Received 🔔', 'Order #' || v_order_short_id || ' received. Accept within 30 seconds.', NEW.id, 'order');

        -- COD Alert
        IF (NEW.payment_method::text = 'COD') THEN
            INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
            VALUES (v_customer_id, 'customer', 'Keep Cash Ready', 'Please keep ₹' || v_amount_fmt || ' ready for delivery.', NEW.id, 'order');
        END IF;
    END IF;

    -- 🔄 STATUS OR ASSIGNMENT UPDATE
    IF (TG_OP = 'UPDATE') THEN
        
        -- Handle Status Changes
        IF (NEW.status::text != OLD.status::text) THEN
            CASE NEW.status::text
                WHEN 'CONFIRMED' THEN
                    INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                    VALUES (v_customer_id, 'customer', 'Order Accepted 👨‍🍳', 'The restaurant has started preparing your order.', NEW.id, 'order');
                
                WHEN 'PREPARING' THEN
                    INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                    VALUES (v_customer_id, 'customer', 'Preparing Your Food', 'Your delicious meal is being prepared.', NEW.id, 'order');
                
                WHEN 'READY' THEN
                    -- Internal Logic: Delivery Request (Wait for acceptance)
                    -- Admin Log
                    INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                    VALUES (v_admin_id, 'admin', 'Order Ready', 'Order #' || v_order_short_id || ' is ready. Searching partners.', NEW.id, 'alert');
                
                WHEN 'PICKED_UP' THEN
                    INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                    VALUES (v_customer_id, 'customer', 'Out for Delivery', 'Your order is on the way. ETA: 20 mins.', NEW.id, 'order');

                WHEN 'DELIVERED' THEN
                    INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                    VALUES (v_customer_id, 'customer', 'Delivered Successfully', 'Order delivered. Enjoy your meal! ⭐', NEW.id, 'order');
                    
                    INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                    VALUES (v_vendor_id, 'vendor', 'Order Delivered', 'Order #' || v_order_short_id || ' has been successfully delivered.', NEW.id, 'order');
                    
                    IF v_delivery_id IS NOT NULL THEN
                        INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                        VALUES (v_delivery_id, 'delivery', 'Delivery Completed', 'Order #' || v_order_short_id || ' marked as delivered.', NEW.id, 'order');
                    END IF;

                WHEN 'CANCELLED' THEN
                    INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                    VALUES (v_customer_id, 'customer', 'Order Cancelled', 'The restaurant couldn’t accept your order. Refund initiated if applicable.', NEW.id, 'order');
                    
                    INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                    VALUES (v_vendor_id, 'vendor', 'Order Cancelled', 'Order #' || v_order_short_id || ' has been cancelled by customer.', NEW.id, 'order');
                    
                    IF v_delivery_id IS NOT NULL THEN
                        INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                        VALUES (v_delivery_id, 'delivery', 'Delivery Cancelled', 'Order #' || v_order_short_id || ' has been cancelled.', NEW.id, 'order');
                    END IF;
            END CASE;
        END IF;

        -- Handle Rider Assignment
        IF (v_delivery_id IS NOT NULL AND (OLD.delivery_partner_id IS NULL OR OLD.delivery_partner_id::text != v_delivery_id::text)) THEN
            INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
            VALUES (v_customer_id, 'customer', 'Rider Assigned 🚴', COALESCE(v_rider_name, 'Rider') || ' will deliver your order. Track live now.', NEW.id, 'order');
            
            INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
            VALUES (v_vendor_id, 'vendor', 'Delivery Partner Assigned', COALESCE(v_rider_name, 'Rider') || ' will pick up order #' || v_order_short_id || '.', NEW.id, 'order');
            
            INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
            VALUES (v_delivery_id, 'delivery', 'New Delivery Assigned', 'You have been assigned order #' || v_order_short_id, NEW.id, 'order');
        END IF;

        -- Handle Refund
        IF (NEW.payment_status::text = 'REFUNDED' AND OLD.payment_status::text != 'REFUNDED') THEN
            INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
            VALUES (v_customer_id, 'customer', 'Refund Successful', '₹' || v_amount_fmt || ' has been credited successfully.', NEW.id, 'refund');
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Ensure the function is owned by postgres to have full permissions
ALTER FUNCTION public.master_notification_handler() OWNER TO postgres;

-- REBIND MASTER TRIGGER
DROP TRIGGER IF EXISTS tr_master_notifications ON public.orders;
CREATE TRIGGER tr_master_notifications
AFTER INSERT OR UPDATE ON public.orders
FOR EACH ROW
EXECUTE FUNCTION public.master_notification_handler();

-- ============================================
-- 4. REALTIME & RLS RE-ENFORCE
-- ============================================
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Unified notification policy" ON public.notifications;
CREATE POLICY "Unified notification policy" ON public.notifications 
    FOR ALL USING (auth.uid() = user_id) 
    WITH CHECK (auth.uid() = user_id);

-- Ensure Realtime is on (DROP/CREATE Publication is safer)
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

COMMIT;

-- VERIFY CLEANLINESS
SELECT trigger_name, event_object_table FROM information_schema.triggers WHERE event_object_table = 'orders';
