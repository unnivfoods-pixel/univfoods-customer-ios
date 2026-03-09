-- 💎 THE GOLD STANDARD LEDGER (V5)
-- "No Cent Unaccounted": Ledger Entries, COD Tracking, and Financial Audit Trails

BEGIN;

-- 1. Ensure Ledger Table exists
CREATE TABLE IF NOT EXISTS public.wallet_transactions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL,
    role text NOT NULL,
    type text NOT NULL, -- CREDIT, DEBIT, REFUND
    amount numeric NOT NULL,
    balance_after numeric,
    source text, -- ORDER_PAYOUT, BANK_DISPATCH, CASH_DEPOSIT
    reference_id uuid, -- Order ID or Settlement ID
    created_at timestamptz DEFAULT now()
);

-- 2. ENHANCED FINANCIAL TRIGGER
-- This version adds Ledger entries for every wallet movement
CREATE OR REPLACE FUNCTION finalize_mission_financials()
RETURNS TRIGGER AS $$
DECLARE
    v_vendor_share numeric;
    v_rider_share numeric;
    v_platform_share numeric;
    v_commission_rate numeric;
    v_new_vendor_bal numeric;
    v_new_rider_bal numeric;
BEGIN
    IF (NEW.status = 'delivered' AND OLD.status != 'delivered') THEN
        
        -- 1. Payout Calculation
        SELECT (commission_rate/100.0) INTO v_commission_rate FROM public.vendors WHERE id = NEW.vendor_id;
        v_commission_rate := COALESCE(v_commission_rate, 0.15); 
        
        v_platform_share := NEW.total * v_commission_rate;
        v_vendor_share := NEW.total - v_platform_share;
        v_rider_share := 40 + (NEW.total * 0.05);

        NEW.vendor_payout := v_vendor_share;
        NEW.rider_payout := v_rider_share;
        NEW.platform_commission := v_platform_share;

        -- 2. UPDATE VENDOR WALLET & LEDGER
        INSERT INTO public.wallets (user_id, role, balance)
        VALUES (NEW.vendor_id, 'VENDOR', v_vendor_share)
        ON CONFLICT (user_id, role) DO UPDATE 
        SET balance = wallets.balance + v_vendor_share, updated_at = now()
        RETURNING balance INTO v_new_vendor_bal;

        INSERT INTO public.wallet_transactions (user_id, role, type, amount, balance_after, source, reference_id)
        VALUES (NEW.vendor_id, 'VENDOR', 'CREDIT', v_vendor_share, v_new_vendor_bal, 'ORDER_PAYOUT', NEW.id);

        -- 3. UPDATE RIDER WALLET & LEDGER
        INSERT INTO public.wallets (user_id, role, balance)
        VALUES (NEW.delivery_partner_id, 'RIDER', v_rider_share)
        ON CONFLICT (user_id, role) DO UPDATE 
        SET balance = wallets.balance + v_rider_share, updated_at = now()
        RETURNING balance INTO v_new_rider_bal;

        INSERT INTO public.wallet_transactions (user_id, role, type, amount, balance_after, source, reference_id)
        VALUES (NEW.delivery_partner_id, 'RIDER', 'CREDIT', v_rider_share, v_new_rider_bal, 'ORDER_PAYOUT', NEW.id);

        -- 4. COD DEBT REGISTRY
        IF (NEW.payment_method = 'COD') THEN
            UPDATE public.delivery_riders 
            SET cod_held = COALESCE(cod_held, 0) + NEW.total 
            WHERE id = NEW.delivery_partner_id;
            
            NEW.payment_state := 'COD_HELD_BY_RIDER';
            
            INSERT INTO public.notifications (user_id, title, message, type)
            VALUES (NEW.delivery_partner_id, '🚨 COD DEBT ADDED', 'You collected ₹' || NEW.total || ' in cash. Ledger synced.', 'FINANCIAL');
        ELSE
            NEW.payment_state := 'PAID_SUCCESS';
        END IF;

        INSERT INTO public.notifications (user_id, title, message, type)
        VALUES (NEW.vendor_id, '💰 MISSION COMPLETED', '₹' || v_vendor_share || ' credited for Order #' || NEW.id, 'FINANCIAL');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. UPDATED SETTLEMENT LEDGER
CREATE OR REPLACE FUNCTION atomic_payout_handler()
RETURNS TRIGGER AS $$
DECLARE
    v_new_bal numeric;
BEGIN
    -- SUCCESS: Finalize Dispatch and Log Ledger
    IF (NEW.status = 'processed' AND OLD.status = 'pending') THEN
        UPDATE public.wallets 
        SET locked_balance = locked_balance - NEW.amount 
        WHERE user_id = NEW.entity_id AND role = NEW.role
        RETURNING balance INTO v_new_bal;
        
        INSERT INTO public.wallet_transactions (user_id, role, type, amount, balance_after, source, reference_id)
        VALUES (NEW.entity_id, NEW.role, 'DEBIT', NEW.amount, v_new_bal, 'BANK_DISPATCH', NEW.id);

        INSERT INTO public.notifications (user_id, title, message, type)
        VALUES (NEW.entity_id, 'DISPATCH SUCCESS', '₹' || NEW.amount || ' wired to bank. Ledger updated.', 'FINANCIAL');
    END IF;

    -- FAIL: Restore and Log (No ledger for fail, just notification)
    IF (NEW.status = 'failed' AND OLD.status = 'pending') THEN
        UPDATE public.wallets 
        SET locked_balance = locked_balance - NEW.amount,
            balance = balance + NEW.amount 
        WHERE user_id = NEW.entity_id AND role = NEW.role;
        
        INSERT INTO public.notifications (user_id, title, message, type)
        VALUES (NEW.entity_id, 'DISPATCH FAILED', 'Funds restored to Mission Wallet.', 'FINANCIAL');
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. FORCE REALTIME ON LEDGER
ALTER TABLE public.wallet_transactions REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE public.wallet_transactions;

COMMIT;
