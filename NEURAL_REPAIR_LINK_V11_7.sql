-- 📡 NEURAL REPAIR & LINK (V11.7)
-- Targeted fix for Support System Real-time and Demo Connectivity

BEGIN;

-- 1. DATABASE HEALING (Missing Subject Column)
ALTER TABLE public.support_chats ADD COLUMN IF NOT EXISTS subject TEXT DEFAULT 'Live Support';

-- 2. SECURITY OVERRIDE (Total Bypass for Demo/Forced IDs)
-- We disable RLS on these tables so that GUEST_USER and other non-auth IDs can communicate.
ALTER TABLE public.support_chats DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_messages DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_tickets DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.ticket_messages DISABLE ROW LEVEL SECURITY;

-- 3. REAL-TIME PULSE REFRESH
-- Ensure the publication includes all support tables
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

-- 4. TEST SIGNAL
INSERT INTO public.support_chats (user_id, user_type, status, priority, subject)
VALUES ('SYSTEM_V11_LINK', 'SYSTEM', 'BOT', 'NORMAL', 'Neural Link Established')
ON CONFLICT DO NOTHING;

COMMIT;

SELECT 'NEURAL LINK V11.7 ONLINE - RLS BYPASSED' as mission_status;
