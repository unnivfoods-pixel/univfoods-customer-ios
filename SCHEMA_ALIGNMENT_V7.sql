-- 🛰️ EMERGENCY SCHEMA ALIGNMENT (V7)
-- Unified fix for missing tables, missing columns, and real-time synchronization.

BEGIN;

-- 1. Support Infrastructure Creation
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

-- 2. Legacy Column Enforcement (for pre-existing tables)
DO $$ 
BEGIN
    ALTER TABLE public.support_tickets ADD COLUMN IF NOT EXISTS context_tag text;
    ALTER TABLE public.support_tickets ADD COLUMN IF NOT EXISTS role text DEFAULT 'RIDER';
    ALTER TABLE public.support_tickets ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();
EXCEPTION WHEN OTHERS THEN 
    NULL;
END $$;

-- 3. Performance Indexes
CREATE INDEX IF NOT EXISTS idx_support_tickets_user_id ON public.support_tickets(user_id);
CREATE INDEX IF NOT EXISTS idx_support_tickets_status ON public.support_tickets(status);
CREATE INDEX IF NOT EXISTS idx_ticket_messages_ticket_id ON public.ticket_messages(ticket_id);

-- 4. Utility Functions & Triggers
CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS tr_update_support_tickets_modtime ON public.support_tickets;
CREATE TRIGGER tr_update_support_tickets_modtime
    BEFORE UPDATE ON public.support_tickets
    FOR EACH ROW
    EXECUTE PROCEDURE update_modified_column();

-- 5. Real-time Broadcasting Configuration
ALTER TABLE public.support_tickets REPLICA IDENTITY FULL;
ALTER TABLE public.ticket_messages REPLICA IDENTITY FULL;

-- Ensure Publication is caught up
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

COMMIT;

NOTIFY pgrst, 'reload schema';
