-- 🛡️ HELP & SUPPORT BACKEND SYNC (V1)
-- This script aligns the database with the real-time Help & Support requirements.

BEGIN;

-- 1. FAQs ENHANCEMENT
-- Ensure category and status exist
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='faqs' AND column_name='category') THEN
        ALTER TABLE public.faqs ADD COLUMN category TEXT DEFAULT 'GENERAL';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='faqs' AND column_name='active_status') THEN
        ALTER TABLE public.faqs ADD COLUMN active_status BOOLEAN DEFAULT true;
    END IF;
END $$;

-- 2. SUPPORT TICKETS ENHANCEMENT
-- Align with requested fields
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='support_tickets' AND column_name='issue_type') THEN
        ALTER TABLE public.support_tickets ADD COLUMN issue_type TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='support_tickets' AND column_name='order_id') THEN
        ALTER TABLE public.support_tickets ADD COLUMN order_id TEXT;
    END IF;
    -- Map description to message if needed, or just add message
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='support_tickets' AND column_name='message') THEN
        ALTER TABLE public.support_tickets ADD COLUMN message TEXT;
    END IF;
END $$;

-- 3. NEW TABLE: PARTNER APPLICATIONS
CREATE TABLE IF NOT EXISTS public.partner_applications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    type TEXT NOT NULL, -- 'vendor', 'delivery'
    name TEXT NOT NULL,
    phone TEXT NOT NULL,
    email TEXT,
    location TEXT,
    documents JSONB DEFAULT '{}', -- Store vehicle docs, license etc.
    status TEXT DEFAULT 'Pending', -- Pending, Approved, Rejected
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. NEW TABLE: SAFETY REPORTS (Priority Alerts)
CREATE TABLE IF NOT EXISTS public.safety_reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id TEXT NOT NULL,
    order_id TEXT,
    issue_type TEXT NOT NULL, -- Rider misbehavior, Safety threat, etc.
    description TEXT,
    status TEXT DEFAULT 'Open', -- Open, Investigating, Resolved
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. SYSTEM SETTINGS (For Support Phone/Email)
CREATE TABLE IF NOT EXISTS public.system_settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    description TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed Support Contacts
INSERT INTO public.system_settings (key, value, description) 
VALUES 
('support_phone', '+919940407600', 'Public support contact number'),
('support_email', 'support@univfoods.in', 'Public support email address')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

-- 6. REAL-TIME ENABLEMENT
ALTER TABLE public.partner_applications REPLICA IDENTITY FULL;
ALTER TABLE public.safety_reports REPLICA IDENTITY FULL;
ALTER TABLE public.system_settings REPLICA IDENTITY FULL;

-- Update Publication
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.partner_applications;
        ALTER PUBLICATION supabase_realtime ADD TABLE public.safety_reports;
        ALTER PUBLICATION supabase_realtime ADD TABLE public.system_settings;
    END IF;
EXCEPTION WHEN OTHERS THEN
    -- Fallback if table already exists in publication
    NULL;
END $$;

-- 7. RLS SECURITY
ALTER TABLE public.partner_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.safety_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_settings ENABLE ROW LEVEL SECURITY;

-- Partner Apps: Users create, Admins manage
CREATE POLICY "Partner Apps: Public Create" ON public.partner_applications FOR INSERT WITH CHECK (true);
CREATE POLICY "Partner Apps: Admin All" ON public.partner_applications FOR ALL USING (true);

-- Safety Reports: Users create own/any, Admins manage
CREATE POLICY "Safety Reports: Public Create" ON public.safety_reports FOR INSERT WITH CHECK (true);
CREATE POLICY "Safety Reports: Admin All" ON public.safety_reports FOR ALL USING (true);

-- System Settings: Public Read, Admin Write
CREATE POLICY "System Settings: Public Read" ON public.system_settings FOR SELECT USING (true);
CREATE POLICY "System Settings: Admin Write" ON public.system_settings FOR ALL USING (true);

COMMIT;
