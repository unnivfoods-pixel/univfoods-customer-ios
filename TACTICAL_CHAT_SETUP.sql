-- 🛰️ TACTICAL COMMAND CHAT INFRASTRUCTURE
-- Enables real-time two-way communication between Riders/Vendors and Admin.

BEGIN;

CREATE TABLE IF NOT EXISTS public.ticket_messages (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    ticket_id uuid REFERENCES public.support_tickets(id) ON DELETE CASCADE,
    sender_id uuid REFERENCES auth.users(id),
    message text NOT NULL,
    is_admin boolean DEFAULT false,
    created_at timestamptz DEFAULT now()
);

-- Enable Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.ticket_messages;

-- RLS Policies
ALTER TABLE public.ticket_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own ticket messages" ON public.ticket_messages
FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM public.support_tickets 
        WHERE id = ticket_messages.ticket_id 
        AND user_id = auth.uid()
    )
);

CREATE POLICY "Users can send messages to own tickets" ON public.ticket_messages
FOR INSERT WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.support_tickets 
        WHERE id = ticket_messages.ticket_id 
        AND user_id = auth.uid()
    )
);

COMMIT;
