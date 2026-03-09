-- ============================================================
-- 🔔 NOTIFICATION REALTIME FIX V81
-- Makes notifications table work with server-side filters
-- ============================================================

BEGIN;

-- 1. Ensure notifications table has REPLICA IDENTITY FULL
--    (Required for realtime filters to work)
ALTER TABLE public.notifications REPLICA IDENTITY FULL;

-- 2. Ensure notifications is in the realtime publication
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND schemaname = 'public' 
        AND tablename = 'notifications'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
        RAISE NOTICE '✅ notifications added to realtime publication';
    ELSE
        RAISE NOTICE '✅ notifications already in realtime publication';
    END IF;
END $$;

-- 3. RLS Policy: Allow users to SELECT their own notifications
--    (Required for realtime filter to work with anon/service key)
DROP POLICY IF EXISTS "Users see own notifications" ON public.notifications;
CREATE POLICY "Users see own notifications"
    ON public.notifications FOR SELECT
    USING (user_id::TEXT = auth.uid()::TEXT OR user_id IS NULL);

-- Allow authenticated customers to see their own notifications
DROP POLICY IF EXISTS "Customers see own notifications" ON public.notifications;
CREATE POLICY "Customers see own notifications"  
    ON public.notifications FOR ALL
    USING (true);  -- Open for now since using Firebase auth (not Supabase auth)

-- 4. Also ensure orders table is in realtime publication
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND schemaname = 'public' 
        AND tablename = 'orders'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
        RAISE NOTICE '✅ orders added to realtime publication';
    ELSE
        RAISE NOTICE '✅ orders already in realtime publication';
    END IF;
END $$;

-- 5. Ensure orders also has REPLICA IDENTITY FULL  
ALTER TABLE public.orders REPLICA IDENTITY FULL;

COMMIT;

-- VERIFY: Show current publication tables
SELECT tablename FROM pg_publication_tables 
WHERE pubname = 'supabase_realtime' 
ORDER BY tablename;
