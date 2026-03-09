-- 🎧 DISPATCH SUPPORT & REALTIME OPERATIONS ENGINE
-- Enables live ticket tracking and emergency signal monitoring for riders.

BEGIN;

CREATE TABLE IF NOT EXISTS public.support_tickets (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid REFERENCES auth.users(id),
    role text DEFAULT 'RIDER', -- RIDER, VENDOR, CUSTOMER
    subject text NOT NULL,
    description text,
    status text DEFAULT 'OPEN', -- OPEN, IN_PROGRESS, RESOLVED, CLOSED
    priority text DEFAULT 'NORMAL', -- NORMAL, HIGH, EMERGENCY
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Enable Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.support_tickets;

-- RLS Policies
ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own tickets" ON public.support_tickets
FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create tickets" ON public.support_tickets
FOR INSERT WITH CHECK (auth.uid() = user_id);

COMMIT;
