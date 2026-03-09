-- ==========================================================
-- 🛠 SUPPORT TERMINAL REPAIR V12 - MESSAGE RELAY & VISIBILITY
-- ==========================================================
-- 🎯 MISSION: Fix "messages not going to admin" and ensure phone visibility in Support.

BEGIN;

-- 1. FIX RLS POLICIES (Allowing Firebase/Guest IDs via sender_id check)
-- Dropping old restrictive policies
DROP POLICY IF EXISTS "Messages: User View Own" ON public.support_messages;
DROP POLICY IF EXISTS "Messages: User Create" ON public.support_messages;
DROP POLICY IF EXISTS "Chats: User View Own" ON public.support_chats;
DROP POLICY IF EXISTS "Chats: User Create" ON public.support_chats;
DROP POLICY IF EXISTS "Support: Users see own tickets" ON public.support_tickets;
DROP POLICY IF EXISTS "Support: Users create tickets" ON public.support_tickets;
DROP POLICY IF EXISTS "Support: Users see own ticket messages" ON public.ticket_messages;
DROP POLICY IF EXISTS "Support: Users send messages" ON public.ticket_messages;

-- A. Support Chats & Messages
CREATE POLICY "Chats: User View/Create" ON public.support_chats 
FOR ALL USING (
    auth.uid()::text = user_id OR 
    (auth.uid() IS NULL AND user_id IS NOT NULL)
);

CREATE POLICY "Messages: User Insert" ON public.support_messages 
FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.support_chats WHERE id = chat_id AND user_id = sender_id)
);

CREATE POLICY "Messages: User Select" ON public.support_messages
FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.support_chats WHERE id = chat_id AND user_id = sender_id)
);

-- B. Support Tickets & Ticket Messages
CREATE POLICY "Tickets: User View/Create" ON public.support_tickets
FOR ALL USING (
    auth.uid()::text = user_id OR 
    (auth.uid() IS NULL AND user_id IS NOT NULL)
);

CREATE POLICY "TicketMessages: User Insert" ON public.ticket_messages
FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.support_tickets WHERE id = ticket_id AND user_id = sender_id)
);

CREATE POLICY "TicketMessages: User Select" ON public.ticket_messages
FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.support_tickets WHERE id = ticket_id AND user_id = sender_id)
);

-- Ensure public access to support tables if RLS is partially blocking anon
ALTER TABLE public.support_chats FORCE ROW LEVEL SECURITY;
ALTER TABLE public.support_messages FORCE ROW LEVEL SECURITY;
ALTER TABLE public.support_tickets FORCE ROW LEVEL SECURITY;
ALTER TABLE public.ticket_messages FORCE ROW LEVEL SECURITY;

-- 2. ENHANCE VISIBILITY FOR ADMIN (Real-time mapping helper)
-- Users often want to see "Customer Name (9876543210)" in the list.
CREATE OR REPLACE VIEW public.support_chats_with_profiles AS
SELECT 
    sc.*,
    cp.full_name as customer_name,
    cp.phone as customer_phone
FROM public.support_chats sc
LEFT JOIN public.customer_profiles cp ON sc.user_id = cp.id;

-- 3. SPEED UP LOOKUPS
CREATE INDEX IF NOT EXISTS idx_support_messages_chat_id ON public.support_messages(chat_id);
CREATE INDEX IF NOT EXISTS idx_support_chats_user_id ON public.support_chats(user_id);

-- 4. FIX GUEST SUPPORT TICKET LOGIC (The UUID crash)
CREATE OR REPLACE FUNCTION public.get_or_create_order_support_v3(
    p_order_id TEXT,
    p_user_id TEXT
)
RETURNS TEXT AS $$
DECLARE
    v_ticket_id TEXT;
BEGIN
    -- Use TEXT based comparisons for safety across ID types
    SELECT id::text INTO v_ticket_id 
    FROM public.support_tickets 
    WHERE order_id::text = p_order_id AND status != 'closed'
    LIMIT 1;

    IF v_ticket_id IS NULL THEN
        -- Insert with TEXT user_id if column allows, otherwise standard UUID path
        -- But here we use a safe insert block
        BEGIN
            INSERT INTO public.support_tickets (user_id, order_id, subject, status, priority)
            VALUES (p_user_id, p_order_id::uuid, 'Order Support: ' || SUBSTRING(p_order_id, 1, 8), 'open', 'high')
            RETURNING id::text INTO v_ticket_id;
        EXCEPTION WHEN OTHERS THEN
             -- Fallback if user_id is strictly UUID in current schema
             INSERT INTO public.support_tickets (user_id, order_id, subject, status, priority)
             VALUES (CASE WHEN p_user_id ~ '^[0-9a-fA-F-]{36}$' THEN p_user_id::uuid ELSE NULL END, p_order_id::uuid, 'Order Support', 'open', 'high')
             RETURNING id::text INTO v_ticket_id;
        END;
    END IF;

    RETURN v_ticket_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;

NOTIFY pgrst, 'reload schema';
