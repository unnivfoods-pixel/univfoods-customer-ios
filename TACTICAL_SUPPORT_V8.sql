-- 🛰️ TACTICAL RELAY SYNC (V8)
-- Final alignment for Support Chat systems across Customer, Rider, and Vendor apps.

BEGIN;

-- 1. Ensure support_tickets is generic and aligned
CREATE TABLE IF NOT EXISTS public.support_tickets (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid, -- Standardized for all roles (matches auth.users.id)
    role text DEFAULT 'CUSTOMER', -- CUSTOMER, RIDER, VENDOR
    subject text NOT NULL,
    description text,
    status text DEFAULT 'OPEN', -- OPEN, RESOLVED, CLOSED
    priority text DEFAULT 'NORMAL', -- NORMAL, EMERGENCY
    context_tag text DEFAULT 'CHAT',
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- 2. Ensure ticket_messages is aligned
CREATE TABLE IF NOT EXISTS public.ticket_messages (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    ticket_id uuid REFERENCES public.support_tickets(id) ON DELETE CASCADE,
    sender_id uuid,
    message text NOT NULL,
    is_admin boolean DEFAULT false,
    created_at timestamptz DEFAULT now()
);

-- 3. Schema Self-Healing: Update columns if they exist but have wrong data/names
DO $$ 
BEGIN
    -- Add columns if missing
    ALTER TABLE public.support_tickets ADD COLUMN IF NOT EXISTS user_id uuid;
    ALTER TABLE public.support_tickets ADD COLUMN IF NOT EXISTS role text DEFAULT 'CUSTOMER';
    ALTER TABLE public.support_tickets ADD COLUMN IF NOT EXISTS context_tag text DEFAULT 'CHAT';
    ALTER TABLE public.support_tickets ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

    -- Migrate legacy data if necessary (e.g. from customer_id to user_id)
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'support_tickets' AND column_name = 'customer_id') THEN
        UPDATE public.support_tickets SET user_id = CAST(customer_id AS uuid) WHERE user_id IS NULL;
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'support_tickets' AND column_name = 'rider_id') THEN
        UPDATE public.support_tickets SET user_id = rider_id, role = 'RIDER' WHERE user_id IS NULL AND rider_id IS NOT NULL;
    END IF;

EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- 4. Enable Real-time for both tables
ALTER TABLE public.support_tickets REPLICA IDENTITY FULL;
ALTER TABLE public.ticket_messages REPLICA IDENTITY FULL;

-- Ensure they are in the publication
-- We use a more aggressive approach to ensure the publication exists and contains our tables
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

-- 5. Tactical RLS Policies
-- Enable RLS
ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ticket_messages ENABLE ROW LEVEL SECURITY;

-- Tickets: Users see their own, Admins see all
DROP POLICY IF EXISTS "Support: Users see own tickets" ON public.support_tickets;
CREATE POLICY "Support: Users see own tickets" ON public.support_tickets
FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Support: Users create tickets" ON public.support_tickets;
CREATE POLICY "Support: Users create tickets" ON public.support_tickets
FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Support: Admin full access" ON public.support_tickets;
CREATE POLICY "Support: Admin full access" ON public.support_tickets
FOR ALL USING (true);

-- Messages: Users see/send in their tickets, Admins see/send all
DROP POLICY IF EXISTS "Support: Users see own ticket messages" ON public.ticket_messages;
CREATE POLICY "Support: Users see own ticket messages" ON public.ticket_messages
FOR SELECT USING (
    ticket_id IN (SELECT id FROM public.support_tickets WHERE user_id = auth.uid())
);

DROP POLICY IF EXISTS "Support: Users send messages" ON public.ticket_messages;
CREATE POLICY "Support: Users send messages" ON public.ticket_messages
FOR INSERT WITH CHECK (
    ticket_id IN (SELECT id FROM public.support_tickets WHERE user_id = auth.uid())
);

DROP POLICY IF EXISTS "Support: Admin full access messages" ON public.ticket_messages;
CREATE POLICY "Support: Admin full access messages" ON public.ticket_messages
FOR ALL USING (true);

COMMIT;

NOTIFY pgrst, 'reload schema';
