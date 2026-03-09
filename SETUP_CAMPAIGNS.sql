-- Create a table for Marketing Campaigns / Manual Push Notifications
CREATE TABLE IF NOT EXISTS public.campaigns (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    image_url TEXT,
    target_audience TEXT DEFAULT 'ALL', -- 'ALL', 'CUSTOMERS', 'VENDORS'
    status TEXT DEFAULT 'sent', -- 'draft', 'scheduled', 'sent'
    sent_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id)
);

-- Enable RLS
ALTER TABLE public.campaigns ENABLE ROW LEVEL SECURITY;

-- Allow Admins to do everything
CREATE POLICY "Admins can manage campaigns" ON public.campaigns
    FOR ALL
    USING (
        auth.uid() IN (
            SELECT id FROM public.admin_users
        )
    );

-- Allow public read (optional, for apps to pull latest announcements if needed)
CREATE POLICY "Public read campaigns" ON public.campaigns
    FOR SELECT
    USING (true);

-- Add 'cancelled_by' and 'cancellation_reason' to orders if not exists
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'cancelled_by') THEN
        ALTER TABLE public.orders ADD COLUMN cancelled_by TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'cancellation_reason') THEN
        ALTER TABLE public.orders ADD COLUMN cancellation_reason TEXT;
    END IF;
      IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'refund_status') THEN
        ALTER TABLE public.orders ADD COLUMN refund_status TEXT DEFAULT 'none'; -- 'none', 'requested', 'processing', 'completed', 'rejected'
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'refund_id') THEN
        ALTER TABLE public.orders ADD COLUMN refund_id TEXT;
    END IF;
END $$;

-- Fix notification policies to ensure insert works for admins
CREATE POLICY "Admins can insert notifications" ON public.notifications
    FOR INSERT
    WITH CHECK (true);
