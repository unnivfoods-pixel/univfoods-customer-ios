-- ✅ UNIVERSAL STATUS ALIGNMENT & LOGISTICS FIX
-- Standardizing statuses across Customer, Vendor, Rider, and Admin apps.

-- 1. TRACKING TIMES REFINEMENT
-- Ensure columns exist
ALTER TABLE public.orders
ADD COLUMN IF NOT EXISTS confirmed_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS ready_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS dispatched_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMP WITH TIME ZONE;

-- 2. ENHANCED LOGISTICS TRIGGER
-- Handles 'ready' status correctly for Rider App synchronization.
CREATE OR REPLACE FUNCTION track_order_phase_times()
RETURNS TRIGGER AS $$
BEGIN
    -- Normalized to lowercase for cross-app compatibility
    NEW.status = LOWER(NEW.status);

    IF (NEW.status = 'preparing' AND (OLD.status IS NULL OR OLD.status = 'pending')) THEN
        NEW.confirmed_at = NOW();
    ELSIF (NEW.status = 'ready' AND OLD.status = 'preparing') THEN
        NEW.ready_at = NOW();
    ELSIF (NEW.status = 'out_for_delivery' AND (OLD.status = 'ready' OR OLD.status = 'preparing')) THEN
        NEW.dispatched_at = NOW();
    ELSIF (NEW.status = 'delivered' AND OLD.status = 'out_for_delivery') THEN
        NEW.delivered_at = NOW();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_order_phase_change ON public.orders;
CREATE TRIGGER on_order_phase_change
BEFORE UPDATE ON public.orders
FOR EACH ROW EXECUTE PROCEDURE track_order_phase_times();

-- 3. NOTIFICATION TRIGGER STATUS SYNC
-- Ensure notifications fire for the 'ready' status so riders get alerted.
CREATE OR REPLACE FUNCTION notify_order_ready()
RETURNS TRIGGER AS $$
BEGIN
    IF (NEW.status = 'ready' AND OLD.status != 'ready') THEN
        -- Notify all riders in the area (General broadcast for available deliveries)
        -- Note: target_type 'riders' is used by our new Notification logic
        INSERT INTO public.notifications (title, body, category, target_type, status, data)
        VALUES (
            '🚚 New Delivery Available!',
            'An order from ' || (SELECT name FROM vendors WHERE id = NEW.vendor_id) || ' is ready for pickup.',
            'INFO',
            'riders',
            'unread',
            jsonb_build_object('order_id', NEW.id, 'type', 'order_ready')
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_order_ready_trigger ON public.orders;
CREATE TRIGGER on_order_ready_trigger
AFTER UPDATE ON public.orders
FOR EACH ROW EXECUTE PROCEDURE notify_order_ready();

-- 4. REALTIME PERMISSIONS
-- Checking if publication exists and is not 'FOR ALL TABLES' before adding
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime' AND NOT puballtables) THEN
        IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'notifications') THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
        END IF;
    END IF;
END $$;

GRANT ALL ON public.notifications TO authenticated;
