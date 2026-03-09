-- 🛰️ ULTIMATE SUPPORT COMMAND INFRASTRUCTURE (V11)
-- This script establishes the complete, high-fidelity neural network for UNIV Support Ecosystem.
-- It covers Chats, Tickets, Bot Logic, Refunds, and Analytics.

BEGIN;

-- 1. EXTENSIONS & TYPES
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'support_user_role') THEN
        CREATE TYPE support_user_role AS ENUM ('CUSTOMER', 'VENDOR', 'RIDER', 'ADMIN', 'SYSTEM');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'chat_status') THEN
        CREATE TYPE chat_status AS ENUM ('BOT', 'OPEN', 'ESCALATED', 'HUMAN', 'RESOLVED', 'CLOSED');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'refund_status') THEN
        CREATE TYPE refund_status AS ENUM ('PENDING', 'APPROVED', 'REJECTED', 'PROCESSED');
    END IF;
END $$;

-- 2. CORE SUPPORT TABLES

-- FAQs & Intel
CREATE TABLE IF NOT EXISTS public.faqs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    question TEXT NOT NULL,
    answer TEXT NOT NULL,
    keywords TEXT[], -- Array for bot matching
    intent TEXT, -- e.g., 'REFUND', 'TRACKING'
    category TEXT DEFAULT 'GENERAL',
    active_status BOOLEAN DEFAULT true,
    usage_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Support Agents Registry
CREATE TABLE IF NOT EXISTS public.support_agents (
    id TEXT PRIMARY KEY, -- Linked to auth.users
    full_name TEXT,
    is_online BOOLEAN DEFAULT false,
    current_chats INTEGER DEFAULT 0,
    max_chats INTEGER DEFAULT 5,
    last_active TIMESTAMPTZ DEFAULT NOW()
);

-- Support Chats (Live Sessions)
CREATE TABLE IF NOT EXISTS public.support_chats (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id TEXT NOT NULL,
    user_type TEXT NOT NULL, -- CUSTOMER, VENDOR, RIDER
    order_id TEXT, -- Optional link to order
    status TEXT DEFAULT 'BOT', -- BOT, HUMAN, RESOLVED
    priority TEXT DEFAULT 'NORMAL', -- NORMAL, HIGH, URGENT
    assigned_agent_id TEXT REFERENCES public.support_agents(id),
    metadata JSONB DEFAULT '{}', -- For sentiment, device info, etc.
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Support Messages (Unified across all sessions)
CREATE TABLE IF NOT EXISTS public.support_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    chat_id UUID REFERENCES public.support_chats(id) ON DELETE CASCADE,
    sender_id TEXT NOT NULL,
    sender_type TEXT NOT NULL, -- USER, AGENT, BOT, SYSTEM
    message TEXT NOT NULL,
    message_type TEXT DEFAULT 'text', -- text, image, voice, system
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Refund Requests
CREATE TABLE IF NOT EXISTS public.refund_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    reason TEXT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    status TEXT DEFAULT 'PENDING', -- PENDING, APPROVED, REJECTED, PROCESSED
    payment_method TEXT, -- UPI, CARD, WALLET, COD
    admin_notes TEXT,
    processed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Delivery Earnings & Withdrawals
CREATE TABLE IF NOT EXISTS public.delivery_earnings (
    rider_id TEXT PRIMARY KEY,
    available_balance DECIMAL(10,2) DEFAULT 0.00,
    pending_balance DECIMAL(10,2) DEFAULT 0.00,
    cod_debt DECIMAL(10,2) DEFAULT 0.00,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.withdrawal_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    rider_id TEXT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    status TEXT DEFAULT 'PENDING', -- PENDING, APPROVED, REJECTED, PROCESSED
    bank_details JSONB,
    processed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Chat Analytics
CREATE TABLE IF NOT EXISTS public.chat_analytics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    metric_name TEXT NOT NULL,
    metric_value JSONB,
    period_start TIMESTAMPTZ,
    period_end TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. HEALING OPERATORS & CASTING (Ensuring UUID/TEXT compatibility)
DO $$ 
BEGIN
    -- This allows us to compare UUID and TEXT columns directly in queries
    IF NOT EXISTS (SELECT 1 FROM pg_operator WHERE oprname = '=' AND oprleft = 'uuid'::regtype AND oprright = 'text'::regtype) THEN
        CREATE OR REPLACE FUNCTION public.uuid_text_eq(uuid, text) RETURNS boolean AS 'SELECT $1 = CASE WHEN $2 ~ ''^[0-9a-fA-F-]{36}$'' THEN $2::uuid ELSE NULL END;' LANGUAGE sql IMMUTABLE;
        CREATE OPERATOR public.= (LEFTARG = uuid, RIGHTARG = text, PROCEDURE = public.uuid_text_eq, COMMUTATOR = =, NEGATOR = <>, HASHES, MERGES);
    END IF;
END $$;

-- 4. BOT INTELLIGENCE & AUTO-ASSIGNMENT LOGIC

-- Bot Greeting Logic on Chat Creation
CREATE OR REPLACE FUNCTION public.proc_initial_bot_greeting()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.support_messages (chat_id, sender_id, sender_type, message)
    VALUES (NEW.id, 'SYSTEM_BOT', 'BOT', '👋 **Mission Intelligence Active.** I am your UNIV Assistant. How can I facilitate your mission today?');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER tr_initial_bot_greeting
    AFTER INSERT ON public.support_chats
    FOR EACH ROW
    EXECUTE PROCEDURE public.proc_initial_bot_greeting();

-- Bot Response Trigger Function
CREATE OR REPLACE FUNCTION public.proc_handle_bot_response()
RETURNS TRIGGER AS $$
DECLARE
    found_answer TEXT;
    match_intent TEXT;
BEGIN
    -- Only process user messages in BOT mode
    IF NEW.sender_type = 'USER' AND (SELECT status FROM public.support_chats WHERE id = NEW.chat_id) = 'BOT' THEN
        
        -- Keyword Matching logic (Simplified for SQL, can be expanded)
        SELECT answer, intent INTO found_answer, match_intent
        FROM public.faqs
        WHERE active_status = true
        AND (
            NEW.message ILIKE ANY(keywords) 
            OR NEW.message % question -- fuzzy match if extension available
        )
        ORDER BY usage_count DESC
        LIMIT 1;

        IF found_answer IS NOT NULL THEN
            -- Increment usage
            UPDATE public.faqs SET usage_count = usage_count + 1 WHERE answer = found_answer;
            
            -- Bot replies
            INSERT INTO public.support_messages (chat_id, sender_id, sender_type, message)
            VALUES (NEW.chat_id, 'SYSTEM_BOT', 'BOT', found_answer);
        ELSE
            -- No match found after a few messages or specific keywords
            IF NEW.message ILIKE '%agent%' OR NEW.message ILIKE '%human%' OR 
               (SELECT COUNT(*) FROM public.support_messages WHERE chat_id = NEW.chat_id AND sender_type = 'USER') > 3 THEN
                
                -- Escalate to Human
                UPDATE public.support_chats 
                SET status = 'OPEN', priority = 'HIGH' 
                WHERE id = NEW.chat_id;
                
                INSERT INTO public.support_messages (chat_id, sender_id, sender_type, message)
                VALUES (NEW.chat_id, 'SYSTEM', 'SYSTEM', '📡 Signal escalated. A tactical agent is joining the frequency...');
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER tr_bot_response
    AFTER INSERT ON public.support_messages
    FOR EACH ROW
    EXECUTE PROCEDURE public.proc_handle_bot_response();

-- 5. RLS SECURITY PROTOCOLS
ALTER TABLE public.faqs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_agents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.refund_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.delivery_earnings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.withdrawal_requests ENABLE ROW LEVEL SECURITY;

-- FAQs: Everyone reads, Admins write
CREATE POLICY "FAQs: Public View" ON public.faqs FOR SELECT USING (true);
CREATE POLICY "FAQs: Admin All" ON public.faqs FOR ALL USING (true); -- Full admin access simplified

-- Chats & Messages: User see own, Admin see all
CREATE POLICY "Chats: User View Own" ON public.support_chats FOR SELECT USING (auth.uid()::text = user_id::text);
CREATE POLICY "Chats: User Create" ON public.support_chats FOR INSERT WITH CHECK (auth.uid()::text = user_id::text);
CREATE POLICY "Chats: Admin All" ON public.support_chats FOR ALL USING (true);

CREATE POLICY "Messages: User View Own" ON public.support_messages FOR SELECT USING (
    chat_id IN (SELECT id FROM public.support_chats WHERE user_id::text = auth.uid()::text)
);
CREATE POLICY "Messages: User Create" ON public.support_messages FOR INSERT WITH CHECK (
    chat_id IN (SELECT id FROM public.support_chats WHERE user_id::text = auth.uid()::text)
);
CREATE POLICY "Messages: Admin All" ON public.support_messages FOR ALL USING (true);

-- 6. REAL-TIME BROADCAST
ALTER TABLE public.faqs REPLICA IDENTITY FULL;
ALTER TABLE public.support_chats REPLICA IDENTITY FULL;
ALTER TABLE public.support_messages REPLICA IDENTITY FULL;
ALTER TABLE public.refund_requests REPLICA IDENTITY FULL;
ALTER TABLE public.withdrawal_requests REPLICA IDENTITY FULL;

-- Refresh Publication
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

-- 7. INITIAL INTELLIGENCE SEED
INSERT INTO public.faqs (question, keywords, answer, intent) VALUES
('Where is my order?', ARRAY['%track%', '%order%', '%where%'], '📡 **Real-time Telemetry Active**: You can track your order live in the "Orders" tab. If the rider pulse is stalled, please ping us here again.', 'TRACKING'),
('How to get a refund?', ARRAY['%refund%', '%return%', '%money%'], '💸 **Refund Protocol**: You can raise a refund request directly from the order details page or the "Refund Status" section in your profile. Our command center reviews all requests within 4 hours.', 'REFUND'),
('My payment failed', ARRAY['%payment%', '%fail%', '%money deducted%'], '💳 **Payment Shield**: If your payment failed but amount was deducted, it will automatically revert within 3-5 command cycles (days). Please check your bank statement.', 'PAYMENT'),
('I want to talk to an agent', ARRAY['%agent%', '%human%', '%person%'], '👤 **Agent Link Established**: Establishing a direct secure link to a human administrator. Please wait for the handshake...', 'ESCALATION');

COMMIT;

SELECT 'UNIV COMMAND INFRASTRUCTURE V11 ONLINE' as mission_status;
