-- 🚨 NUCLEAR IDENTITY & WALLET HARMONY (V14)
-- Purpose: Bulletproof phone-based identity mapping and real-time sync.

BEGIN;

-- 1. Ensure Wallet Integrity (One wallet per user)
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uq_wallet_user_id') THEN
        ALTER TABLE public.wallets ADD CONSTRAINT uq_wallet_user_id UNIQUE (user_id);
    END IF;
END $$;

-- 2. UPGRADE MIGRATION ENGINE (Merging logic)
CREATE OR REPLACE FUNCTION public.migrate_guest_orders_v4(p_guest_id TEXT, p_auth_id TEXT)
RETURNS VOID AS $$
DECLARE
    v_guest_bal DOUBLE PRECISION;
    v_auth_bal DOUBLE PRECISION;
BEGIN
    -- A. MOVE ORDERS
    UPDATE public.orders SET customer_id = p_auth_id WHERE customer_id = p_guest_id;
    
    -- B. MERGE WALLETS
    SELECT balance INTO v_guest_bal FROM public.wallets WHERE user_id = p_guest_id;
    IF FOUND THEN
        SELECT balance INTO v_auth_bal FROM public.wallets WHERE user_id = p_auth_id;
        IF FOUND THEN
            -- Add guest money to existing auth account
            UPDATE public.wallets SET balance = balance + v_guest_bal WHERE user_id = p_auth_id;
            DELETE FROM public.wallets WHERE user_id = p_guest_id;
        ELSE
            -- Move guest account to auth account
            UPDATE public.wallets SET user_id = p_auth_id WHERE user_id = p_guest_id;
        END IF;
    END IF;

    -- C. MOVE ADDRESSES (If any)
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'user_addresses') THEN
        EXECUTE 'UPDATE public.user_addresses SET user_id = $1 WHERE user_id = $2' USING p_auth_id, p_guest_id;
    END IF;
    
    -- D. CONSOLIDATE PROFILE
    -- Move name/email from guest to auth if auth is empty
    UPDATE public.customer_profiles cp
    SET 
        full_name = COALESCE(cp.full_name, g.full_name),
        email = COALESCE(cp.email, g.email)
    FROM public.customer_profiles g
    WHERE cp.id = p_auth_id AND g.id = p_guest_id;
    
    -- Delete guest profile
    DELETE FROM public.customer_profiles WHERE id = p_guest_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. EXTENDED OWNER REPAIRS (Aligning all apps)
DO $$ 
BEGIN
    -- Align Vendors owner_id to TEXT
    ALTER TABLE public.vendors ALTER COLUMN owner_id TYPE TEXT;
EXCEPTION WHEN OTHERS THEN 
    RAISE NOTICE 'Constraint already handled or missing';
END $$;

-- 5. SPEED INDEXING for Phone-based Identity
CREATE INDEX IF NOT EXISTS idx_customer_profiles_phone ON public.customer_profiles(phone);

-- 6. ENSURE REALTIME REPLICA IDENTITY
ALTER TABLE public.wallets REPLICA IDENTITY FULL;
ALTER TABLE public.customer_profiles REPLICA IDENTITY FULL;
ALTER TABLE public.vendors REPLICA IDENTITY FULL;

COMMIT;
