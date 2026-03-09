-- 🚀 DAY 6: WALLET & EARNINGS SYSTEM (ATOMIC TRUTH)
-- Goal: Ensure vendors and riders are paid correctly upon order delivery.

BEGIN;

-- 1. Wallet Tables
CREATE TABLE IF NOT EXISTS public.wallets (
    user_id TEXT PRIMARY KEY, -- Firebase UID
    user_role TEXT NOT NULL, -- 'vendor', 'delivery', 'customer'
    balance DOUBLE PRECISION DEFAULT 0.0,
    currency TEXT DEFAULT 'INR',
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.wallet_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    order_id TEXT, -- Changed to TEXT for compatibility
    amount DOUBLE PRECISION NOT NULL,
    type TEXT NOT NULL, -- 'EARNING', 'WITHDRAWAL', 'REFUND', 'FEE'
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS for Wallets (User can only see their own wallet)
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Wallet Isolation" ON public.wallets;
CREATE POLICY "Wallet Isolation" ON public.wallets
FOR SELECT USING ((user_id::text) = (auth.uid()::text));

ALTER TABLE public.wallet_transactions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Transaction Isolation" ON public.wallet_transactions;
CREATE POLICY "Transaction Isolation" ON public.wallet_transactions
FOR SELECT USING ((user_id::text) = (auth.uid()::text));

-- 2. AUTOMATIC EARNINGS TRIGGER
-- Fires when an order is marked 'DELIVERED'
CREATE OR REPLACE FUNCTION public.process_order_earnings_v1()
RETURNS TRIGGER AS $$
DECLARE
    v_vendor_earning DOUBLE PRECISION;
    v_rider_earning DOUBLE PRECISION;
    v_fixed_rider_fee DOUBLE PRECISION := 40.0; -- Default fixed fee
BEGIN
    -- Only trigger when status moves to DELIVERED
    IF (NEW.order_status = 'DELIVERED' AND (OLD.order_status IS NULL OR OLD.order_status != 'DELIVERED')) THEN
        
        -- A. Calculate Vendor Earnings (Sales - 10% Platform Fee)
        v_vendor_earning := NEW.total_amount * 0.90;
        
        -- Update Vendor Wallet
        INSERT INTO public.wallets (user_id, user_role, balance)
        VALUES (NEW.vendor_id::text, 'vendor', v_vendor_earning)
        ON CONFLICT (user_id) DO UPDATE SET
            balance = public.wallets.balance + v_vendor_earning,
            updated_at = now();

        -- Log Vendor Transaction
        INSERT INTO public.wallet_transactions (user_id, order_id, amount, type, description)
        VALUES (NEW.vendor_id::text, NEW.id::text, v_vendor_earning, 'EARNING', 'Order Delivery Payout (90% after platform fee)');

        -- B. Calculate Rider Earnings (Fixed Fee)
        IF NEW.rider_id IS NOT NULL THEN
            v_rider_earning := v_fixed_rider_fee;
            
            -- Update Rider Wallet
            INSERT INTO public.wallets (user_id, user_role, balance)
            VALUES (NEW.rider_id::text, 'delivery', v_rider_earning)
            ON CONFLICT (user_id) DO UPDATE SET
                balance = public.wallets.balance + v_rider_earning,
                updated_at = now();

            -- Log Rider Transaction
            INSERT INTO public.wallet_transactions (user_id, order_id, amount, type, description)
            VALUES (NEW.rider_id::text, NEW.id::text, v_rider_earning, 'EARNING', 'Delivery Commission (Fixed Fee)');
        END IF;

    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_process_order_earnings ON public.orders;
CREATE TRIGGER trg_process_order_earnings
AFTER UPDATE ON public.orders
FOR EACH ROW
EXECUTE FUNCTION public.process_order_earnings_v1();

COMMIT;
