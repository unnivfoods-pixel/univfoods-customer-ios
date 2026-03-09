-- 🌌 REALTIME MASTER SYNC (THE CENTRAL BRAIN)
-- Consolidates all app interactions into a single, event-driven event hub.
-- Rules: No app-to-app talk. Admin is the controller. Realtime is the heartbeat.

-- 1. INFRASTRUCTURE ALIGNMENT
ALTER TABLE public.delivery_riders 
ADD COLUMN IF NOT EXISTS rejection_count INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS total_completed_missions INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS current_gps_speed NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_location_update TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS heading NUMERIC DEFAULT 0;

ALTER TABLE public.orders
ADD COLUMN IF NOT EXISTS rider_eta TEXT,
ADD COLUMN IF NOT EXISTS cancellation_reason TEXT;

-- 2. REALTIME NOTIFIED EVENT ROUTER (The Core Pulse)
-- This function handles all state changes and pushes notifications/transmissions to appropriate nodes.
CREATE OR REPLACE FUNCTION master_event_hub_router()
RETURNS TRIGGER AS $$
DECLARE
    v_target_user_id UUID;
    v_vendor_name TEXT;
    v_customer_name TEXT;
BEGIN
    -- Get contextual names
    SELECT name INTO v_vendor_name FROM public.vendors WHERE id = NEW.vendor_id;
    SELECT full_name INTO v_customer_name FROM public.customer_profiles WHERE id = NEW.customer_id;

    -- CASE 1: Order Ready -> Call Assignment Engine
    IF (NEW.status = 'ready' AND (OLD.status IS NULL OR OLD.status != 'ready')) THEN
        PERFORM public.find_and_assign_rider(NEW.id);
    END IF;

    -- CASE 2: Rider Assigned -> Notify Customer & Vendor
    IF (NEW.status = 'rider_assigned' AND (OLD.status IS NULL OR OLD.status != 'rider_assigned')) THEN
        -- Notify Customer
        INSERT INTO public.notifications (user_id, title, body, data)
        VALUES (NEW.customer_id, '🚚 Rider Assigned!', 'Hero ' || (SELECT name FROM delivery_riders WHERE id = NEW.rider_id) || ' is on the way to pick up your curry.', jsonb_build_object('order_id', NEW.id, 'type', 'rider_assigned'));
        
        -- Notify Vendor
        INSERT INTO public.notifications (target_type, vendor_id, title, body, data)
        VALUES ('vendors', NEW.vendor_id, 'Rider En Route', 'Rider ' || (SELECT name FROM delivery_riders WHERE id = NEW.rider_id) || ' has accepted the mission.', jsonb_build_object('order_id', NEW.id, 'type', 'rider_assigned'));
    END IF;

    -- CASE 3: Picked Up -> Notify Customer
    IF (NEW.status = 'picked_up' AND OLD.status != 'picked_up') THEN
        INSERT INTO public.notifications (user_id, title, body, data)
        VALUES (NEW.customer_id, '🥘 Order On The Way!', 'Your food has left the kitchen. Track your rider live!', jsonb_build_object('order_id', NEW.id, 'type', 'picked_up'));
    END IF;

    -- CASE 4: Delivered -> Settlement & Global Cleanup
    IF (NEW.status = 'delivered' AND OLD.status != 'delivered') THEN
        -- Cleanup Rider Status
        UPDATE public.delivery_riders 
        SET active_order_id = NULL, 
            total_completed_missions = total_completed_missions + 1,
            last_online_at = NOW()
        WHERE id = NEW.rider_id;

        -- Notify Customer to Rate
        INSERT INTO public.notifications (user_id, title, body, data)
        VALUES (NEW.customer_id, '🎉 Delivered!', 'Hope you enjoy the meal. Please rate your experience.', jsonb_build_object('order_id', NEW.id, 'type', 'delivered'));

        -- Settlement Engine is already triggered by 'on_order_delivered_settle' in CENTRAL_BRAIN_MASTER
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_master_event_hub ON public.orders;
CREATE TRIGGER trg_master_event_hub
AFTER UPDATE ON public.orders
FOR EACH ROW EXECUTE PROCEDURE master_event_hub_router();

-- 3. RIDER GPS & HEALTH MONITOR (Admin Oversight)
-- This logic auto-flags riders if they stop sending GPS pings while on a mission.
CREATE OR REPLACE FUNCTION monitor_rider_mission_health()
RETURNS VOID AS $$
BEGIN
    -- Log Fraud if GPS inactive > 60 sec during active mission
    INSERT INTO public.fraud_logs (rider_id, order_id, reason, severity)
    SELECT id, active_order_id, 'GPS BLACKOUT: Rider inactive for > 60s during delivery', 'HIGH'
    FROM public.delivery_riders
    WHERE active_order_id IS NOT NULL
    AND (NOW() - last_online_at) > INTERVAL '1 minute';
    
    -- Potential: Auto-Notify Admin/Customer
END;
$$ LANGUAGE plpgsql;

-- 4. SUPPORT SYNC (Realtime Admin Visibility)
-- When a rider creates a ticket, notify Admin panel instantly.
CREATE OR REPLACE FUNCTION notify_admin_on_support()
RETURNS TRIGGER AS $$
BEGIN
    -- This will appear in Admin dashboard activity stream via notifications table
    INSERT INTO public.notifications (target_type, title, body, status, data)
    VALUES ('admin', '🆘 Help Signal: ' || NEW.ticket_type, 'Rider id: ' || NEW.rider_id || ' reported: ' || NEW.subject, 'unread', jsonb_build_object('ticket_id', NEW.id, 'type', 'support_alert'));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5. PAYMENT SYSTEM: COD INTEGRITY
-- If rider marks delivered but COD not collected (mismatch)
CREATE OR REPLACE FUNCTION check_cod_integrity()
RETURNS TRIGGER AS $$
BEGIN
    IF (NEW.status = 'delivered' AND NEW.payment_type = 'COD' AND NEW.cod_collected_amount < NEW.total) THEN
        INSERT INTO public.fraud_logs (order_id, rider_id, reason, severity)
        VALUES (NEW.id, NEW.rider_id, 'COD MISMATCH: Collected ₹' || NEW.cod_collected_amount || ' instead of ₹' || NEW.total, 'HIGH');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_cod_integrity ON public.orders;
CREATE TRIGGER trg_cod_integrity
AFTER UPDATE ON public.orders
FOR EACH ROW EXECUTE PROCEDURE check_cod_integrity();

-- 6. FINAL REALTIME PUBLICATION REFRESH
-- Ensure all mission-critical tables are broadcasted.
ALTER PUBLICATION supabase_realtime ADD TABLE public.delivery_riders;
ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
ALTER PUBLICATION supabase_realtime ADD TABLE public.fraud_logs;
ALTER PUBLICATION supabase_realtime ADD TABLE public.support_tickets;
ALTER PUBLICATION supabase_realtime ADD TABLE public.vendor_settlements;

-- 7. SECURITY: ADMIN OVERRIDE RPC
-- Allows Admin to manually reassign or force offline from dashboard
CREATE OR REPLACE FUNCTION admin_force_rider_action(r_id UUID, action_type TEXT)
RETURNS VOID AS $$
BEGIN
    IF action_type = 'OFFLINE' THEN
        UPDATE public.delivery_riders SET is_online = false, active_order_id = NULL WHERE id = r_id;
    ELSIF action_type = 'SUSPEND' THEN
        UPDATE public.delivery_riders SET kyc_status = 'SUSPENDED', is_online = false WHERE id = r_id;
    ELSIF action_type = 'REASSIGN_MISSION' THEN
        -- Implementation for reassignment would call assignment engine again for the specific order
        UPDATE public.delivery_riders SET active_order_id = NULL WHERE id = r_id;
    END IF;
END;
$$ LANGUAGE plpgsql;
