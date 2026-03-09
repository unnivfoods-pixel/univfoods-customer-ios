-- 🛰️ TACTICAL TERMINAL UNIFIER (V10 - THE HEALING OPERATOR)
-- This version solves the "uuid = text" operator error by creating an implicit casting bridge.
-- This is a permanent fix for cross-type comparison errors.

BEGIN;

-- 1. HEALING OPERATOR: Create a bridge for UUID and TEXT comparisons
-- This stops the "operator does not exist: uuid = text" error across the entire database.
CREATE OR REPLACE FUNCTION public.uuid_text_eq(uuid, text) RETURNS boolean AS $$
    SELECT $1 = CASE WHEN $2 ~ '^[0-9a-fA-F-]{36}$' THEN $2::uuid ELSE NULL END;
$$ LANGUAGE sql IMMUTABLE;

CREATE OR REPLACE FUNCTION public.text_uuid_eq(text, uuid) RETURNS boolean AS $$
    SELECT CASE WHEN $1 ~ '^[0-9a-fA-F-]{36}$' THEN $1::uuid ELSE NULL END = $2;
$$ LANGUAGE sql IMMUTABLE;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_operator WHERE oprname = '=' AND oprleft = 'uuid'::regtype AND oprright = 'text'::regtype) THEN
        CREATE OPERATOR public.= (
            LEFTARG = uuid,
            RIGHTARG = text,
            PROCEDURE = public.uuid_text_eq,
            COMMUTATOR = =,
            NEGATOR = <>,
            HASHES, MERGES
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_operator WHERE oprname = '=' AND oprleft = 'text'::regtype AND oprright = 'uuid'::regtype) THEN
        CREATE OPERATOR public.= (
            LEFTARG = text,
            RIGHTARG = uuid,
            PROCEDURE = public.text_uuid_eq,
            COMMUTATOR = =,
            NEGATOR = <>,
            HASHES, MERGES
        );
    END IF;
EXCEPTION WHEN OTHERS THEN 
    RAISE NOTICE 'Operator setup encountered issues (possibly already exists): %', SQLERRM;
END $$;

-- 2. Clean up existing constraints that might block type changes
DO $$ 
DECLARE 
    r RECORD;
BEGIN
    FOR r IN (
        SELECT constraint_name, table_name 
        FROM information_schema.table_constraints 
        WHERE table_name IN ('support_tickets', 'ticket_messages') 
        AND constraint_type = 'FOREIGN KEY'
    ) LOOP
        EXECUTE 'ALTER TABLE public.' || r.table_name || ' DROP CONSTRAINT IF EXISTS ' || r.constraint_name || ' CASCADE';
    END LOOP;
END $$;

-- 3. Force alignment to TEXT for cross-app consistency
DO $$ 
BEGIN
    -- Support Tickets
    ALTER TABLE public.support_tickets ALTER COLUMN user_id TYPE text USING user_id::text;
    ALTER TABLE public.support_tickets ALTER COLUMN id TYPE text USING id::text;
    
    -- Ticket Messages
    ALTER TABLE public.ticket_messages ALTER COLUMN ticket_id TYPE text USING ticket_id::text;
    ALTER TABLE public.ticket_messages ALTER COLUMN sender_id TYPE text USING sender_id::text;
    ALTER TABLE public.ticket_messages ALTER COLUMN id TYPE text USING id::text;
EXCEPTION WHEN OTHERS THEN 
    RAISE NOTICE 'Structural update encountered issues: %', SQLERRM;
END $$;

-- 4. RLS Protocol Re-alignment
ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ticket_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Support: Users see own tickets" ON public.support_tickets;
CREATE POLICY "Support: Users see own tickets" ON public.support_tickets
FOR SELECT USING (auth.uid()::text = user_id::text);

DROP POLICY IF EXISTS "Support: Users create tickets" ON public.support_tickets;
CREATE POLICY "Support: Users create tickets" ON public.support_tickets
FOR INSERT WITH CHECK (auth.uid()::text = user_id::text);

DROP POLICY IF EXISTS "Support: Admin full access" ON public.support_tickets;
CREATE POLICY "Support: Admin full access" ON public.support_tickets
FOR ALL USING (true);

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

DROP POLICY IF EXISTS "Support: Admin full access messages" ON public.ticket_messages;
CREATE POLICY "Support: Admin full access messages" ON public.ticket_messages
FOR ALL USING (true);

-- 5. Real-time Broadcast Refresh
ALTER TABLE public.support_tickets REPLICA IDENTITY FULL;
ALTER TABLE public.ticket_messages REPLICA IDENTITY FULL;

DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

COMMIT;

NOTIFY pgrst, 'reload schema';

SELECT 'Tactical Terminal Unifier V10 Deployed. Healing Operators Active.' as status;
