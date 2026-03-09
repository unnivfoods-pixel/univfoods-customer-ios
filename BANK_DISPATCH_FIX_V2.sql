-- 🏧 REAL-TIME BANK DISPATCH & WALLET SYNCHRONIZATION
-- Ensures balance is immediately debited/locked upon withdrawal request.

BEGIN;

-- 1. Create Handle Settlement function
CREATE OR REPLACE FUNCTION handle_settlement_request()
RETURNS TRIGGER AS $$
BEGIN
    -- Only for Rider/Vendor withdrawals (INITIATED)
    IF (NEW.status = 'pending') THEN
        -- Check if sufficient balance exists
        IF EXISTS (
            SELECT 1 FROM public.wallets 
            WHERE user_id = NEW.entity_id 
            AND role = NEW.role 
            AND balance >= NEW.amount
        ) THEN
            -- Debit Balance and Move to Locked
            UPDATE public.wallets 
            SET balance = balance - NEW.amount,
                locked_balance = locked_balance + NEW.amount,
                updated_at = now()
            WHERE user_id = NEW.entity_id 
            AND role = NEW.role;
            
            -- Log Notification for User
            INSERT INTO public.notifications (user_id, title, message, type)
            VALUES (NEW.entity_id, 'BANK DISPATCH INITIATED', 'Your request for ₹' || NEW.amount || ' is being processed by HQ.', 'FINANCIAL');
        ELSE
            RAISE EXCEPTION 'Insufficient balance for settlement.';
        END IF;
    END IF;

    -- Handle Success (Processed)
    IF (NEW.status = 'processed' AND OLD.status = 'pending') THEN
        UPDATE public.wallets 
        SET locked_balance = locked_balance - NEW.amount,
            updated_at = now()
            WHERE user_id = NEW.entity_id 
            AND role = NEW.role;

        INSERT INTO public.notifications (user_id, title, message, type)
        VALUES (NEW.entity_id, 'BANK DISPATCH SUCCESS', '₹' || NEW.amount || ' has been successfully dispatched to your account.', 'FINANCIAL');
    END IF;

    -- Handle Failure
    IF (NEW.status = 'failed' AND OLD.status = 'pending') THEN
        UPDATE public.wallets 
        SET locked_balance = locked_balance - NEW.amount,
            balance = balance + NEW.amount,
            updated_at = now()
            WHERE user_id = NEW.entity_id 
            AND role = NEW.role;

        INSERT INTO public.notifications (user_id, title, message, type)
        VALUES (NEW.entity_id, 'BANK DISPATCH FAILED', 'Settlement failed. Funds restored to your mission wallet.', 'FINANCIAL');
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. Attach Trigger
DROP TRIGGER IF EXISTS tr_handle_settlement ON public.settlements;
CREATE TRIGGER tr_handle_settlement
AFTER INSERT OR UPDATE ON public.settlements
FOR EACH ROW EXECUTE FUNCTION handle_settlement_request();

COMMIT;
