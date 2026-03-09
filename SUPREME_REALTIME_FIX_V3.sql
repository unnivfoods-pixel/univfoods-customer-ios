-- 👑 THE SUPREME REAL-TIME FINANCIAL FIX (V3)
-- "Fucking Fix it" Edition: Unified Wallets, Real-time Payouts, and Tactical Support

BEGIN;

-- 1. Ensure Support Infrastructure exists with correct role support
CREATE TABLE IF NOT EXISTS public.support_tickets (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid REFERENCES auth.users(id),
    role text DEFAULT 'RIDER', -- RIDER, VENDOR, CUSTOMER
    subject text NOT NULL,
    description text,
    status text DEFAULT 'OPEN', -- OPEN, IN_PROGRESS, RESOLVED, CLOSED
    priority text DEFAULT 'NORMAL',
    context_tag text,
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

-- 2. Consolidate Wallets with Role support
CREATE TABLE IF NOT EXISTS public.wallets (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL,
    role text NOT NULL, -- VENDOR, RIDER, CUSTOMER
    balance numeric DEFAULT 0.0,
    locked_balance numeric DEFAULT 0.0,
    updated_at timestamptz DEFAULT now(),
    UNIQUE(user_id, role)
);

-- 3. Atomic Settlement & Notification Logic
CREATE OR REPLACE FUNCTION atomic_payout_handler()
RETURNS TRIGGER AS $$
BEGIN
    -- INIT: Lock Funds immediately on request
    IF (NEW.status = 'pending') THEN
        IF EXISTS (SELECT 1 FROM public.wallets WHERE user_id = NEW.entity_id AND role = NEW.role AND balance >= NEW.amount) THEN
            UPDATE public.wallets 
            SET balance = balance - NEW.amount, 
                locked_balance = locked_balance + NEW.amount 
            WHERE user_id = NEW.entity_id AND role = NEW.role;
            
            INSERT INTO public.notifications (user_id, title, message, type)
            VALUES (NEW.entity_id, 'DISPATCH INITIATED', 'Your ₹' || NEW.amount || ' dispatch has reached HQ.', 'FINANCIAL');
        ELSE
            RAISE EXCEPTION 'Insufficient Mission Funds.';
        END IF;
    END IF;

    -- SUCCESS: Finalize Dispatch
    IF (NEW.status = 'processed' AND OLD.status = 'pending') THEN
        UPDATE public.wallets 
        SET locked_balance = locked_balance - NEW.amount 
        WHERE user_id = NEW.entity_id AND role = NEW.role;
        
        INSERT INTO public.notifications (user_id, title, message, type)
        VALUES (NEW.entity_id, 'DISPATCH SUCCESS', '₹' || NEW.amount || ' has been successfully wired.', 'FINANCIAL');
    END IF;

    -- FAIL: Restore Liquid Capital
    IF (NEW.status = 'failed' AND OLD.status = 'pending') THEN
        UPDATE public.wallets 
        SET locked_balance = locked_balance - NEW.amount,
            balance = balance + NEW.amount 
        WHERE user_id = NEW.entity_id AND role = NEW.role;
        
        INSERT INTO public.notifications (user_id, title, message, type)
        VALUES (NEW.entity_id, 'DISPATCH FAILED', 'Operational error. Funds restored to Mission Wallet.', 'FINANCIAL');
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_atomic_payout ON public.settlements;
CREATE TRIGGER tr_atomic_payout 
AFTER INSERT OR UPDATE ON public.settlements
FOR EACH ROW EXECUTE FUNCTION atomic_payout_handler();

-- 4. RPC for COD Depot with Real-time Signal
CREATE OR REPLACE FUNCTION driver_deposit_cod(p_driver_id uuid, p_amount numeric)
RETURNS void AS $$
BEGIN
    UPDATE public.delivery_riders 
    SET cod_held = COALESCE(cod_held, 0) - p_amount 
    WHERE id = p_driver_id;
    
    INSERT INTO public.notifications (user_id, title, message, type)
    VALUES (p_driver_id, 'COD DEBT CLEARED', 'Platform debt of ₹' || p_amount || ' has been purged.', 'FINANCIAL');
END;
$$ LANGUAGE plpgsql security definer;

-- 5. Force Publication
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR TABLE 
    public.orders, 
    public.vendors, 
    public.delivery_riders, 
    public.notifications, 
    public.wallets, 
    public.settlements,
    public.support_tickets,
    public.ticket_messages;

COMMIT;
