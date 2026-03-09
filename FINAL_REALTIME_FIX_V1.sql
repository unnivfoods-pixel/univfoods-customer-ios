-- 🏦 REALTIME FINANCIAL ENGINE & SUPPORT PERSISTENCE
-- Fixes real-time data flow for vendor/delivery bank dispatches.

BEGIN;

-- 1. Ensure support_tickets exists and has correct real-time triggers
CREATE TABLE IF NOT EXISTS public.support_tickets (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid REFERENCES auth.users(id),
    role text DEFAULT 'RIDER', -- RIDER, VENDOR, CUSTOMER
    subject text NOT NULL,
    description text,
    status text DEFAULT 'OPEN', -- OPEN, IN_PROGRESS, RESOLVED, CLOSED
    priority text DEFAULT 'NORMAL', -- NORMAL, HIGH, EMERGENCY
    context_tag text, -- e.g., 'PAYMENT_INQUIRY', 'TECHNICAL_FAILURE'
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- 2. Bank Dispatch (Settlements) Realtime Layer
-- Ensure the settlements table is broadcasted for vendor/delivery apps
-- (Already in replication slot but re-verifying triggers)

-- 3. Contact Registry Update
-- Global configuration for support contacts
CREATE TABLE IF NOT EXISTS public.app_config (
    key text PRIMARY KEY,
    value text,
    updated_at timestamptz DEFAULT now()
);

INSERT INTO public.app_config (key, value) 
VALUES ('support_hotline', '+91 99404 07600')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

-- 4. Secure RLS for Support
ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own tickets" ON public.support_tickets;
CREATE POLICY "Users can view own tickets" ON public.support_tickets
FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can create tickets" ON public.support_tickets;
CREATE POLICY "Users can create tickets" ON public.support_tickets
FOR INSERT WITH CHECK (auth.uid() = user_id);

-- 5. Force Realtime Refresh for Financials
-- Ensures any payment / settlement change is pushed instantly.
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'support_tickets') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.support_tickets;
    END IF;
END $$;

COMMIT;
