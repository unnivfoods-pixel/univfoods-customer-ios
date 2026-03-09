-- 👑 SUPREME FINANCIAL & NOTIFICATION CONSOLIDATION (Play Store Release)
-- Purpose: Unified Escrow, Wallets, Settlements, and FCM Bridge

-- 1. BASE REPAIR & FINANCIAL STORAGE
-- -----------------------------------------------------------------------------------
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS payment_state text DEFAULT 'PENDING';
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS commission_amount numeric DEFAULT 0.0;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS rider_fee numeric DEFAULT 0.0;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS refund_id text;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS cod_collected_at timestamptz;

-- Wallets System (Unified)
CREATE TABLE IF NOT EXISTS public.wallets (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL,
    role text NOT NULL, -- VENDOR, RIDER, CUSTOMER
    balance numeric DEFAULT 0.0,
    locked_balance numeric DEFAULT 0.0,
    updated_at timestamptz DEFAULT now(),
    UNIQUE(user_id, role)
);

-- Payments History
CREATE TABLE IF NOT EXISTS public.payments (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id uuid REFERENCES public.orders(id) ON DELETE SET NULL,
    user_id uuid,
    amount numeric NOT NULL,
    type text DEFAULT 'payment', -- payment, refund, adjustment
    method text, -- upi, card, cod
    status text DEFAULT 'success',
    created_at timestamptz DEFAULT now()
);

-- Settlement Engine
CREATE TABLE IF NOT EXISTS public.settlements (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    entity_id uuid NOT NULL, -- vendor_id or rider_id
    role text, -- VENDOR, RIDER
    amount numeric NOT NULL,
    status text DEFAULT 'pending', -- pending, processed, failed
    bank_ref text,
    created_at timestamptz DEFAULT now(),
    processed_at timestamptz
);

-- 2. AUTOMATION TRIGGERS
-- -----------------------------------------------------------------------------------

-- A. Automatic Wallet Entry on Order Delivery
CREATE OR REPLACE FUNCTION process_financials_on_delivery()
RETURNS TRIGGER AS $$
DECLARE
    v_vendor_id uuid;
    v_rider_id uuid;
    v_total numeric;
    v_commission numeric;
    v_rider_pay numeric;
    v_vendor_pay numeric;
BEGIN
    -- Only trigger when order is delivered
    IF (NEW.status = 'delivered' AND OLD.status != 'delivered') THEN
        v_total := NEW.total;
        
        -- 1. Calculate Earnings (Defaults if not set)
        -- Admin usually sets these, but we fallback
        v_commission := v_total * 0.10; -- 10% Platform fee
        v_rider_pay := 40.0; -- Flat 40 for now + bonus
        v_vendor_pay := v_total - v_commission;

        -- 2. Update Vendor Wallet
        INSERT INTO public.wallets (user_id, role, balance)
        VALUES (NEW.vendor_id, 'VENDOR', v_vendor_pay)
        ON CONFLICT (user_id, role) DO UPDATE 
        SET balance = wallets.balance + v_vendor_pay, updated_at = now();

        -- 3. Update Rider Wallet
        INSERT INTO public.wallets (user_id, role, balance)
        VALUES (NEW.delivery_partner_id, 'RIDER', v_rider_pay)
        ON CONFLICT (user_id, role) DO UPDATE 
        SET balance = wallets.balance + v_rider_pay, updated_at = now();

        -- 4. Mark Payment State
        IF (NEW.payment_method = 'cod') THEN
            NEW.payment_state := 'COD_COLLECTED';
            NEW.cod_collected_at := now();
        ELSE
            NEW.payment_state := 'SETTLED';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_order_financials ON public.orders;
CREATE TRIGGER tr_order_financials
BEFORE UPDATE OF status ON public.orders
FOR EACH ROW EXECUTE FUNCTION process_financials_on_delivery();

-- B. Handle Settlement Payouts (Deduct from Wallet)
CREATE OR REPLACE FUNCTION handle_settlement_processed()
RETURNS TRIGGER AS $$
BEGIN
    IF (NEW.status = 'processed' AND OLD.status = 'pending') THEN
        UPDATE public.wallets 
        SET balance = balance - NEW.amount, updated_at = now()
        WHERE user_id = NEW.entity_id AND role = NEW.role;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_settlement_payout ON public.settlements;
CREATE TRIGGER tr_settlement_payout
AFTER UPDATE OF status ON public.settlements
FOR EACH ROW EXECUTE FUNCTION handle_settlement_processed();

-- 3. NOTIFICATION LOGS (For Admin Broadcasting)
-- -----------------------------------------------------------------------------------
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS target_audience text DEFAULT 'ALL';
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS image_url text;

-- 4. REAL-TIME REGISTRY
-- -----------------------------------------------------------------------------------
-- Force Realtime for financial tables
ALTER TABLE public.wallets REPLICA IDENTITY FULL;
ALTER TABLE public.payments REPLICA IDENTITY FULL;
ALTER TABLE public.settlements REPLICA IDENTITY FULL;

-- Re-sync Publication
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR TABLE 
    public.orders, 
    public.vendors, 
    public.delivery_riders, 
    public.notifications, 
    public.wallets, 
    public.settlements;

-- 5. RPC FOR CASH COLLECTION (COD DEPOT)
CREATE OR REPLACE FUNCTION driver_deposit_cod(p_driver_id uuid, p_amount numeric)
RETURNS void AS $$
BEGIN
    -- Deduct from cod_held (if you have that column)
    UPDATE public.delivery_riders 
    SET cod_held = COALESCE(cod_held, 0) - p_amount 
    WHERE id = p_driver_id;
    
    -- Log as payment from rider to platform
    INSERT INTO public.payments (user_id, amount, type, method)
    VALUES (p_driver_id, p_amount, 'cod_deposit', 'cash');
END;
$$ LANGUAGE plpgsql security definer;
