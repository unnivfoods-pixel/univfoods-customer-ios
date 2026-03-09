-- 1. ADD FCM COLUMNS (Safe)
ALTER TABLE public.customer_profiles ADD COLUMN IF NOT EXISTS fcm_token TEXT;
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS fcm_token TEXT;
ALTER TABLE public.delivery_riders ADD COLUMN IF NOT EXISTS fcm_token TEXT;

-- 2. CREATE NOTIFICATIONS TABLE (Safe)
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID,
    role TEXT, 
    title TEXT,
    body TEXT,
    data JSONB,
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 3. ENABLE REALTIME SAFELY (Avoids the 'already exists' error)
DO $$
BEGIN
    -- Check and add notifications
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'notifications') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
    END IF;

    -- Check and add orders
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'orders') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
    END IF;

    -- Check and add vendors
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'vendors') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.vendors;
    END IF;
END $$;

-- 4. BYPASS RLS FOR NOTIFICATIONS (So Admin can see them)
ALTER TABLE public.notifications DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders REPLICA IDENTITY FULL;
