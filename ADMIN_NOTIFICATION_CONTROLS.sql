-- 🚩 ADMIN NOTIFICATION CONTROL PANEL
-- Functions for Admin to send manual and bulk notifications

BEGIN;

-- 1. FUNCTION: SEND TO SPECIFIC USER
CREATE OR REPLACE FUNCTION admin_send_notification(
    p_user_id uuid,
    p_app_type text,
    p_title text,
    p_message text,
    p_type text DEFAULT 'alert',
    p_order_id uuid DEFAULT NULL
)
RETURNS uuid AS $$
DECLARE
    v_notif_id uuid;
BEGIN
    INSERT INTO public.notifications (user_id, app_type, title, message, type, order_id)
    VALUES (p_user_id, p_app_type, p_title, p_message, p_type, p_order_id)
    RETURNING id INTO v_notif_id;
    
    RETURN v_notif_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. FUNCTION: BROADCAST TO ALL CUSTOMERS
CREATE OR REPLACE FUNCTION admin_broadcast_promo(
    p_title text,
    p_message text
)
RETURNS integer AS $$
DECLARE
    v_count integer;
BEGIN
    INSERT INTO public.notifications (user_id, app_type, title, message, type)
    SELECT id, 'customer', p_title, p_message, 'promo'
    FROM public.customer_profiles;
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. FUNCTION: SEND TO SPECIFIC VENDOR
CREATE OR REPLACE FUNCTION admin_notify_vendor(
    p_vendor_id uuid,
    p_title text,
    p_message text
)
RETURNS uuid AS $$
BEGIN
    RETURN admin_send_notification(p_vendor_id, 'vendor', p_title, p_message, 'alert');
END;
$$ LANGUAGE plpgsql;

-- 4. SYSTEM ALERTS (FOR ADMIN)
-- Triggers for Admin dashboard alerts
CREATE OR REPLACE FUNCTION notify_admin_system_event()
RETURNS TRIGGER AS $$
DECLARE
    v_admin_id uuid;
BEGIN
    -- Get first admin or specific system user
    -- In a real app, you'd notify all users with 'admin' role
    -- For now, we insert a generic admin notification
    
    CASE TG_TABLE_NAME
        WHEN 'vendors' THEN
            IF (NEW.is_approved != OLD.is_approved AND NEW.is_approved = TRUE) THEN
                -- No need for admin alert on approval, focus on registration
            ELSIF (TG_OP = 'INSERT') THEN
                INSERT INTO public.notifications (user_id, app_type, title, message, type)
                VALUES (NEW.owner_id, 'admin', 'New Vendor Registered', 'Vendor: ' || NEW.name || ' is awaiting approval.', 'alert');
            END IF;
            
        WHEN 'delivery_riders' THEN
            IF (TG_OP = 'INSERT') THEN
                INSERT INTO public.notifications (user_id, app_type, title, message, type)
                VALUES (NEW.user_id, 'admin', 'New Rider Registered', 'Rider: ' || NEW.name || ' is awaiting approval.', 'alert');
            END IF;
    END CASE;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_admin_vendor_alert ON public.vendors;
CREATE TRIGGER tr_admin_vendor_alert
AFTER INSERT OR UPDATE ON public.vendors
FOR EACH ROW EXECUTE FUNCTION notify_admin_system_event();

DROP TRIGGER IF EXISTS tr_admin_rider_alert ON public.delivery_riders;
CREATE TRIGGER tr_admin_rider_alert
AFTER INSERT ON public.delivery_riders
FOR EACH ROW EXECUTE FUNCTION notify_admin_system_event();

COMMIT;
