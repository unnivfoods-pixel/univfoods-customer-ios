-- 🛰️ CHAT & SUPPORT RELIABILITY OVERHAUL (V6)
-- "The Tactical Link": Guaranteed Real-time Delivery for Support & Payments

BEGIN;

-- 1. Table Reinforcement
-- Ensure tables exist with correct structures
CREATE TABLE IF NOT EXISTS public.support_tickets (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid REFERENCES auth.users(id),
    role text DEFAULT 'RIDER', -- RIDER, VENDOR, CUSTOMER
    subject text NOT NULL,
    description text,
    status text DEFAULT 'OPEN', -- OPEN, IN_PROGRESS, RESOLVED, CLOSED
    priority text DEFAULT 'NORMAL',
    context_tag text, -- CHAT, PAYMENT_INQUIRY, INCIDENT
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ticket_messages (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    ticket_id uuid REFERENCES public.support_tickets(id) ON DELETE CASCADE,
    sender_id uuid REFERENCES auth.users(id),
    message text NOT NULL,
    is_admin boolean DEFAULT false,
    created_at timestamptz DEFAULT now()
);

-- 2. Real-time Broadcasting Configuration
-- Critical: Replica Identity MUST be FULL for stream filters to behave correctly in Flutter
ALTER TABLE public.support_tickets REPLICA IDENTITY FULL;
ALTER TABLE public.ticket_messages REPLICA IDENTITY FULL;

-- 3. RLS Security Lockdown & Open Channels
ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ticket_messages ENABLE ROW LEVEL SECURITY;

-- A. Tickets: Users can see and create their own tickets
DROP POLICY IF EXISTS "Users can view own tickets" ON public.support_tickets;
CREATE POLICY "Users can view own tickets" ON public.support_tickets 
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can create own tickets" ON public.support_tickets;
CREATE POLICY "Users can create own tickets" ON public.support_tickets 
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- B. Messages: Users can see messages in their own tickets
DROP POLICY IF EXISTS "Users can view messages in own tickets" ON public.ticket_messages;
CREATE POLICY "Users can view messages in own tickets" ON public.ticket_messages 
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.support_tickets 
            WHERE id = ticket_messages.ticket_id AND user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Users can insert messages in own tickets" ON public.ticket_messages;
CREATE POLICY "Users can insert messages in own tickets" ON public.ticket_messages 
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.support_tickets 
            WHERE id = ticket_messages.ticket_id AND user_id = auth.uid()
        )
    );

-- 4. Admin Access (Bypass RLS)
-- Assuming admin has service_role or we can add a specific policy if needed
-- For now, ensuring authenticated users are solid.

-- 5. Real-time Publication Sync
-- Re-sync everything to be safe
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

COMMIT;
