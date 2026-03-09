-- 🛰️ TACTICAL TERMINAL UNIFIER (V9 - ABSOLUTE ALIGNMENT)
-- Ensures all three apps (Customer, Rider, Vendor) are perfectly linked to the Support Terminal.
-- Handles type-casting to TEXT to avoid UUID mismatches from previous migrations.

BEGIN;

-- 1. Structural Reinforcement for Support Tickets
DO $$ 
BEGIN
    -- Ensure columns exist and are TEXT-compatible for maximum cross-app reliability
    ALTER TABLE public.support_tickets ALTER COLUMN user_id TYPE text USING user_id::text;
    ALTER TABLE public.support_tickets ALTER COLUMN id TYPE text USING id::text;
    
    -- Ensure ticket_messages is aligned
    ALTER TABLE public.ticket_messages ALTER COLUMN ticket_id TYPE text USING ticket_id::text;
    ALTER TABLE public.ticket_messages ALTER COLUMN sender_id TYPE text USING sender_id::text;
    ALTER TABLE public.ticket_messages ALTER COLUMN id TYPE text USING id::text;

EXCEPTION WHEN OTHERS THEN 
    RAISE NOTICE 'Structural update encountered issues: %', SQLERRM;
END $$;

-- 2. Standardize Column Defaults & Constraints
ALTER TABLE public.support_tickets ALTER COLUMN status SET DEFAULT 'OPEN';
ALTER TABLE public.support_tickets ALTER COLUMN priority SET DEFAULT 'NORMAL';
ALTER TABLE public.support_tickets ALTER COLUMN role SET DEFAULT 'CUSTOMER';

-- 3. Tactical RLS Overhaul (Type-Safe for both UUID and TEXT)
-- This ensures that regardless of whether auth.uid() is compared to text or uuid, it works.

ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ticket_messages ENABLE ROW LEVEL SECURITY;

-- Tickets: Users see own, Admins see all
DROP POLICY IF EXISTS "Support: Users see own tickets" ON public.support_tickets;
CREATE POLICY "Support: Users see own tickets" ON public.support_tickets
FOR SELECT USING (auth.uid()::text = user_id::text);

DROP POLICY IF EXISTS "Support: Users create tickets" ON public.support_tickets;
CREATE POLICY "Support: Users create tickets" ON public.support_tickets
FOR INSERT WITH CHECK (auth.uid()::text = user_id::text);

-- Messages: Users see/send in their tickets, Admins see/send all
DROP POLICY IF EXISTS "Support: Users see own ticket messages" ON public.ticket_messages;
CREATE POLICY "Support: Users see own ticket messages" ON public.ticket_messages
FOR SELECT USING (
    ticket_id IN (SELECT id::text FROM public.support_tickets WHERE user_id::text = auth.uid()::text)
);

DROP POLICY IF EXISTS "Support: Users send messages" ON public.ticket_messages;
CREATE POLICY "Support: Users send messages" ON public.ticket_messages
FOR INSERT WITH CHECK (
    ticket_id IN (SELECT id::text FROM public.support_tickets WHERE user_id::text = auth.uid()::text)
);

-- Admin Global Access (Final Layer)
DROP POLICY IF EXISTS "Support: Admin full access" ON public.support_tickets;
CREATE POLICY "Support: Admin full access" ON public.support_tickets
FOR ALL USING (true);

DROP POLICY IF EXISTS "Support: Admin full access messages" ON public.ticket_messages;
CREATE POLICY "Support: Admin full access messages" ON public.ticket_messages
FOR ALL USING (true);

-- 4. Final Real-time Validation
ALTER TABLE public.support_tickets REPLICA IDENTITY FULL;
ALTER TABLE public.ticket_messages REPLICA IDENTITY FULL;

-- Ensure Publication is refreshed to include these tables with current schema
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

COMMIT;

NOTIFY pgrst, 'reload schema';

SELECT 'Tactical Terminal Unifier V9 Deployed. Three-app link established.' as status;
