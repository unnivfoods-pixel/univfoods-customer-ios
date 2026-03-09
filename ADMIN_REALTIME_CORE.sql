-- ✅ ADMIN REALTIME CORE SYSTEM
-- Comprehensive backend setup for Customer Control, Orders, Support, and Tracking

-- 1. EXTEND CUSTOMER PROFILES
ALTER TABLE public.customer_profiles 
ADD COLUMN IF NOT EXISTS is_blocked BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS cod_disabled BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS max_order_limit NUMERIC DEFAULT 5000,
ADD COLUMN IF NOT EXISTS account_status TEXT DEFAULT 'Active', -- Active, Suspended, Restricted
ADD COLUMN IF NOT EXISTS total_orders INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS cancel_count INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS cod_failure_count INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS total_spent NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS wallet_balance NUMERIC DEFAULT 0;

-- 2. ENHANCE ORDERS TABLE
ALTER TABLE public.orders
ADD COLUMN IF NOT EXISTS rider_id UUID REFERENCES public.delivery_riders(id),
ADD COLUMN IF NOT EXISTS payment_type TEXT DEFAULT 'COD', -- COD, WALLET, ONLINE
ADD COLUMN IF NOT EXISTS payment_status TEXT DEFAULT 'PENDING',
ADD COLUMN IF NOT EXISTS eta TEXT,
ADD COLUMN IF NOT EXISTS is_force_cancelled BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS distance_remaining TEXT,
ADD COLUMN IF NOT EXISTS last_gps_update TIMESTAMP WITH TIME ZONE;

-- 3. SUPPORT SYSTEM TABLES
CREATE TABLE IF NOT EXISTS public.support_tickets (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    customer_id UUID REFERENCES public.customer_profiles(id),
    rider_id UUID REFERENCES public.delivery_riders(id),
    order_id UUID REFERENCES public.orders(id),
    subject TEXT,
    description TEXT,
    status TEXT DEFAULT 'OPEN', -- OPEN, RESOLVED, CLOSED
    priority TEXT DEFAULT 'NORMAL', -- NORMAL, HIGH, URGENT
    ticket_type TEXT -- DELAY, REFUND, WRONG_ITEM, OTHER
);

CREATE TABLE IF NOT EXISTS public.support_chats (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    ticket_id UUID REFERENCES public.support_tickets(id),
    sender_id UUID, -- auth.uid()
    message TEXT,
    is_admin BOOLEAN DEFAULT FALSE
);

-- 4. REFUND MANAGEMENT
CREATE TABLE IF NOT EXISTS public.refunds (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    order_id UUID REFERENCES public.orders(id),
    customer_id UUID REFERENCES public.customer_profiles(id),
    amount NUMERIC NOT NULL,
    reason TEXT,
    status TEXT DEFAULT 'INITIATED', -- INITIATED, COMPLETED, FAILED
    transaction_id TEXT,
    estimated_time TEXT
);

-- 5. FRAUD CONTROL LOGS
CREATE TABLE IF NOT EXISTS public.fraud_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    customer_id UUID REFERENCES public.customer_profiles(id),
    order_id UUID REFERENCES public.orders(id),
    reason TEXT,
    severity TEXT, -- LOW, MEDIUM, HIGH
    action_taken TEXT
);

-- 6. GLOBAL SETTINGS (REALTIME CONTROL)
-- Already exists as app_settings, but ensure keys
INSERT INTO public.app_settings (key, value)
VALUES 
('delivery_radius', '{"km": 15, "enabled": true}'::jsonb),
('cod_settings', '{"global_enabled": true, "max_value": 2000}'::jsonb),
('fraud_thresholds', '{"max_cancellations": 3, "max_cod_failures": 2}'::jsonb)
ON CONFLICT (key) DO NOTHING;

-- 7. ENABLE REALTIME ON NEW TABLES
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime' AND NOT puballtables) THEN
        IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'support_tickets') THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.support_tickets;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'support_chats') THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.support_chats;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'refunds') THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.refunds;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'fraud_logs') THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.fraud_logs;
        END IF;
    END IF;
END $$;

-- 8. TRIGGERS FOR SYNCING
-- Update order status when refund is initiated
CREATE OR REPLACE FUNCTION handle_refund_status()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        UPDATE public.orders 
        SET payment_status = NEW.status 
        WHERE id = NEW.order_id;
    ELSIF (TG_OP = 'UPDATE') THEN
        UPDATE public.orders 
        SET payment_status = NEW.status 
        WHERE id = NEW.order_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_refund_status_change
AFTER INSERT OR UPDATE ON public.refunds
FOR EACH ROW EXECUTE PROCEDURE handle_refund_status();

-- 9. RLS POLICIES FOR ADMIN & USERS
ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.refunds ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fraud_logs ENABLE ROW LEVEL SECURITY;

-- Support Tickets
CREATE POLICY "Users can view own tickets" ON public.support_tickets FOR SELECT USING (auth.uid() = customer_id);
CREATE POLICY "Users can create tickets" ON public.support_tickets FOR INSERT WITH CHECK (auth.uid() = customer_id);
CREATE POLICY "Admin full access tickets" ON public.support_tickets FOR ALL USING (true);

-- Support Chats
CREATE POLICY "Users can see own chats" ON public.support_chats FOR SELECT USING (
    ticket_id IN (SELECT id FROM public.support_tickets WHERE customer_id = auth.uid())
);
CREATE POLICY "Users can send chats" ON public.support_chats FOR INSERT WITH CHECK (
    ticket_id IN (SELECT id FROM public.support_tickets WHERE customer_id = auth.uid())
);
CREATE POLICY "Admin full access chats" ON public.support_chats FOR ALL USING (true);

-- Refunds & Fraud (Admin Only mostly)
CREATE POLICY "Users can see own refunds" ON public.refunds FOR SELECT USING (auth.uid() = customer_id);
CREATE POLICY "Admin full access refunds" ON public.refunds FOR ALL USING (true);
CREATE POLICY "Admin full access fraud" ON public.fraud_logs FOR ALL USING (true);

-- 10. AUTH CHECKS
-- Add trigger to check if user is blocked before login (simulated via RLS or specific logic)
-- In Supabase, we can't easily block login from SQL (it's handled by Auth), 
-- but we can restrict all RLS policies if is_blocked is true.

CREATE OR REPLACE FUNCTION is_user_blocked()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.customer_profiles 
        WHERE id = auth.uid() AND is_blocked = TRUE
    );
END;
$$ LANGUAGE plpgsql;

-- Apply block check to existing orders policy
DROP POLICY IF EXISTS "Customers can view own orders" ON public.orders;
CREATE POLICY "Customers can view own orders"
ON public.orders
FOR SELECT
USING (auth.uid() = customer_id AND NOT is_user_blocked());

DROP POLICY IF EXISTS "Public orders insert" ON public.orders;
CREATE POLICY "Public orders insert" ON public.orders
FOR INSERT
WITH CHECK (NOT is_user_blocked());
