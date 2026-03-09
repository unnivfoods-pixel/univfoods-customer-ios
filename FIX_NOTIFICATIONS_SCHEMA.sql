-- 🔔 FIX NOTIFICATIONS SCHEMA AND TRIGGERS (FINAL VERSION)
-- Resolves "column order_id does not exist" and "column total_amount does not exist" errors.

-- 1. Ensure order_id column exists in notifications
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'notifications' AND column_name = 'order_id') THEN
        ALTER TABLE public.notifications ADD COLUMN order_id UUID REFERENCES public.orders(id) ON DELETE CASCADE;
    END IF;
END $$;

-- 2. Ensure data column exists for deep linking metadata
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'notifications' AND column_name = 'data') THEN
        ALTER TABLE public.notifications ADD COLUMN data JSONB DEFAULT '{}'::jsonb;
    END IF;
END $$;

-- 3. Fix triggers to use correct 'total' column instead of 'total_amount'
CREATE OR REPLACE FUNCTION notify_order_placed()
RETURNS TRIGGER AS $$
BEGIN
    -- Customer notification
    INSERT INTO public.notifications (user_id, title, body, role, priority, order_id, deep_link, data)
    VALUES (
        NEW.customer_id,
        '🎉 Order Placed Successfully!',
        'Your order #' || SUBSTRING(NEW.id::text, 1, 8) || ' has been placed. Total: ₹' || COALESCE(NEW.total::text, '0'),
        'CUSTOMER',
        'NORMAL',
        NEW.id,
        '/orders/' || NEW.id,
        jsonb_build_object('order_id', NEW.id, 'type', 'order_placed')
    );
    
    -- Vendor notification (HIGH PRIORITY)
    INSERT INTO public.notifications (user_id, title, body, role, priority, order_id, deep_link, data)
    VALUES (
        NEW.vendor_id,
        '🔔 New Order Received!',
        'New order #' || SUBSTRING(NEW.id::text, 1, 8) || ' received. Amount: ₹' || COALESCE(NEW.total::text, '0'),
        'VENDOR',
        'HIGH',
        NEW.id,
        '/orders/' || NEW.id,
        jsonb_build_object('order_id', NEW.id, 'type', 'new_order')
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION notify_payment_success()
RETURNS TRIGGER AS $$
BEGIN
    -- Only if payment status changed to success (case insensitive check)
    IF (LOWER(NEW.payment_status) = 'paid') AND (OLD.payment_status IS NULL OR LOWER(OLD.payment_status) != 'paid') THEN
        
        -- Notify customer
        INSERT INTO public.notifications (user_id, title, body, role, priority, order_id, deep_link, data)
        VALUES (
            NEW.customer_id,
            '💰 Payment Successful',
            'Payment successful for order #' || SUBSTRING(NEW.id::text, 1, 8) || '. Amount: ₹' || COALESCE(NEW.total::text, '0'),
            'CUSTOMER',
            'NORMAL',
            NEW.id,
            '/orders/' || NEW.id,
            jsonb_build_object('order_id', NEW.id, 'type', 'payment_success')
        );
    END IF;
    
    -- COD notification for rider
    IF LOWER(NEW.payment_method) = 'cod' AND NEW.status = 'CONFIRMED' THEN
        IF NEW.delivery_partner_id IS NOT NULL THEN
            INSERT INTO public.notifications (user_id, title, body, role, priority, order_id, deep_link, data)
            VALUES (
                NEW.delivery_partner_id,
                '💵 COD Collection',
                'Collect ₹' || COALESCE(NEW.total::text, '0') || ' from customer for order #' || SUBSTRING(NEW.id::text, 1, 8),
                'RIDER',
                'HIGH',
                NEW.id,
                '/deliveries/' || NEW.id,
                jsonb_build_object('order_id', NEW.id, 'type', 'cod_collection')
            );
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. Re-apply Triggers
DROP TRIGGER IF EXISTS on_order_placed ON public.orders;
CREATE TRIGGER on_order_placed
    AFTER INSERT ON public.orders
    FOR EACH ROW
    EXECUTE FUNCTION notify_order_placed();

DROP TRIGGER IF EXISTS on_payment_status_changed ON public.orders;
CREATE TRIGGER on_payment_status_changed
    AFTER UPDATE ON public.orders
    FOR EACH ROW
    EXECUTE FUNCTION notify_payment_success();

-- ✅ Schema and Triggers updated to match the actual database structure ('total' column).
