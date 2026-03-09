-- 1. Create notifications table
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    user_id UUID, -- Optional: targeted user (customer/rider)
    role TEXT, -- ADMIN, CUSTOMER, DELIVERY, VENDOR
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    data JSONB DEFAULT '{}'::jsonb,
    is_read BOOLEAN DEFAULT false
);

-- 2. Add sample notifications for testing
INSERT INTO public.notifications (role, title, body) VALUES 
('ADMIN', 'Welcome to Admin Pulse', 'Your real-time notification system is active.'),
('ADMIN', 'System Alert', 'Notifications are now linked to the backend.');

-- 3. Enable Realtime for the table
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;

-- 4. Enable RLS
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- 5. Policies (Public read for now for demo simplicity, or authenticated)
CREATE POLICY "Public read notifications" ON public.notifications FOR SELECT USING (true);
CREATE POLICY "Public insert notifications" ON public.notifications FOR INSERT WITH CHECK (true);
CREATE POLICY "Public update notifications" ON public.notifications FOR UPDATE USING (true);
