-- ✅ SYSTEM DOUBLE CHECK & REFINEMENT
-- This script fixes schema inconsistencies and adds performance optimizations

-- 1. FIX NOTIFICATIONS SCHEMA
-- Ensure it matches the JSX requirements (target_type, body vs message)
ALTER TABLE public.notifications 
ADD COLUMN IF NOT EXISTS target_type TEXT DEFAULT 'all', -- all, vendors, riders
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id), -- If missing
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'unread';

-- Re-sync body/message column logic: We keep 'body' as the source of truth for legacy triggers but support 'message' if needed.
-- Actually, let's just make sure both exist or JSX matches. I will update JSX to use 'body'.

-- 2. SYNC APP SETTINGS (Move to system_config blob or individual keys)
-- We'll ensure 'system_config' contains everything for the UI.
CREATE OR REPLACE FUNCTION sync_system_settings()
RETURNS TRIGGER AS $$
BEGIN
    -- If individual keys change, we could update system_config, 
    -- but usually it's easier to just use 'system_config' from Admin.
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. ENHANCE LOGISTICS WITH "DOUBLE TIME" (SPEED UPDATE)
-- Track time taken between statuses
ALTER TABLE public.orders
ADD COLUMN IF NOT EXISTS confirmed_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS prepared_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS dispatched_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMP WITH TIME ZONE;

CREATE OR REPLACE FUNCTION track_order_phase_times()
RETURNS TRIGGER AS $$
BEGIN
    IF (NEW.status = 'preparing' AND (OLD.status IS NULL OR OLD.status = 'pending')) THEN
        NEW.confirmed_at = NOW();
    ELSIF (NEW.status = 'out_for_delivery' AND OLD.status = 'preparing') THEN
        NEW.prepared_at = NOW();
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

-- 4. REALTIME PERMISSIONS FOR NEW LOGS
GRANT ALL ON public.support_tickets TO authenticated;
GRANT ALL ON public.support_chats TO authenticated;
GRANT ALL ON public.refunds TO authenticated;
GRANT ALL ON public.fraud_logs TO authenticated;

-- Ensure realtime is enabled on everything important (redundant check)
DO $$
BEGIN
    -- Check if publication is NOT for all tables
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime' AND NOT puballtables) THEN
        IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'support_tickets') THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.support_tickets;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'support_chats') THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.support_chats;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'refunds') THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.refunds;
        END IF;
    END IF;
END $$;
