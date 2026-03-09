-- 🛰️ BOUTIQUE TERMINAL UPGRADE: BUSY MODE & NOTIFICATIONS (V12)
-- Resolves: "Busy ui test is broken" and "Notification is missing"

BEGIN;

-- 1. ENHANCE VENDORS SCHEMA
-- Add is_busy to track kitchen overload status
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS is_busy BOOLEAN DEFAULT FALSE;

-- 2. ENSURE REALTIME BROADCAST
-- Force REPLICA IDENTITY FULL to ensure the UI reacts instantly to the toggle
ALTER TABLE public.vendors REPLICA IDENTITY FULL;

-- 3. RE-INIT NOTIFICATIONS PUB
-- Ensure notifications are in the publication
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'notifications') THEN
        BEGIN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
    END IF;
END $$;

COMMIT;

NOTIFY pgrst, 'reload schema';
