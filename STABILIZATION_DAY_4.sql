-- 🚀 DAY 4: REALTIME HUB & SYNC (CORRECTED)
-- Goal: Solidify realtime subscriptions for orders and payments.

BEGIN;

-- 1. REPLICATION ENABLEMENT
-- Ensure the 'supabase_realtime' publication includes the critical tables
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        CREATE PUBLICATION supabase_realtime;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- Add tables to publication
-- This allows Supabase Realtime to broadcast changes to these tables
ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
EXCEPTION WHEN OTHERS THEN NULL;
ALTER PUBLICATION supabase_realtime ADD TABLE public.payments;
EXCEPTION WHEN OTHERS THEN NULL;

-- 2. ENSURE FULL REPLICATION IDENTITY
-- This ensures the 'OLD' record is sent with updates, allowing for status change detection
ALTER TABLE public.orders REPLICA IDENTITY FULL;
ALTER TABLE public.payments REPLICA IDENTITY FULL;

-- 3. REFRESH SCHEMA
NOTIFY pgrst, 'reload schema';

COMMIT;
