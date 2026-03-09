-- 💬 CHAT INFRASTRUCTURE SYNC (V34.2)
-- Purpose: Professional Order-based Chat (Customer ↔ Rider)

BEGIN;

-- 1. Upgrade chat_messages for Role-based tracking
ALTER TABLE public.chat_messages 
ADD COLUMN IF NOT EXISTS sender_role TEXT DEFAULT 'CUSTOMER', -- CUSTOMER, RIDER, VENDOR
ADD COLUMN IF NOT EXISTS receiver_id UUID;

-- 2. Enable Realtime for the table
ALTER TABLE public.chat_messages REPLICA IDENTITY FULL;

-- 3. Policy Reset (Simple check for demo reliability)
-- Note: In production, these should be more restrictive.
DROP POLICY IF EXISTS "Anyone can chat on orders" ON public.chat_messages;
CREATE POLICY "Anyone can chat on orders" ON public.chat_messages 
    FOR ALL USING (true) WITH CHECK (true);

COMMIT;
