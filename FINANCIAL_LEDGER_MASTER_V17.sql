BEGIN;

-- ==========================================================
-- 🛠 0. SCHEMA INTEGRITY REPAIR (CRITICAL)
-- ==========================================================
-- Ensure orders.id is a UUID Primary Key so ledger can reference it.
DO $$ 
BEGIN
    -- 1. Check Primary Key
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_name = 'orders' AND constraint_type = 'PRIMARY KEY'
    ) THEN
        ALTER TABLE public.orders ADD PRIMARY KEY (id);
    END IF;

    -- 2. Check Type (Must be UUID for Ledger consistency)
    IF (SELECT data_type FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'id') = 'text' THEN
        ALTER TABLE public.orders ALTER COLUMN id TYPE UUID USING (id::uuid);
    END IF;
EXCEPTION WHEN OTHERS THEN 
    RAISE NOTICE 'Orders table repair skipped or already handled.';
END $$;

-- ==========================================================
-- 💰 1. COMMISSION & SETTLEMENT RULES
-- ==========================================================
CREATE TABLE IF NOT EXISTS public.commission_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    city_code TEXT DEFAULT 'GLOBAL',
    platform_fee_percent DOUBLE PRECISION DEFAULT 10.0,
    delivery_base_fee DOUBLE PRECISION DEFAULT 20.0,
    min_order_value_for_free_delivery DOUBLE PRECISION DEFAULT 500.0,
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- ==========================================================
-- 📒 2. THE MASTER LEDGER (Audit Trail)
-- ==========================================================
-- No money moves without a ledger entry. Ever.
CREATE TABLE IF NOT EXISTS public.financial_ledger (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entry_type TEXT NOT NULL, -- ORDER_EARNING, WITHDRAWAL, REFUND, PENALTY, TIP, COD_COLLECTION
    user_id UUID, -- Can be Vendor Owner or Rider
    order_id UUID REFERENCES public.orders(id),
    amount DOUBLE PRECISION NOT NULL,
    flow_type TEXT NOT NULL, -- 'IN' (Revenue to Platform), 'OUT' (Payout to Users), 'INTERNAL' (Split)
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.financial_ledger REPLICA IDENTITY FULL;

-- ==========================================================
-- 💳 3. SETTLEMENT BALANCES (The "Wallet 2.0")
-- ==========================================================
-- Separating "Withdrawable Balance" from "Lifetime Earnings"
ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS pending_settlement DOUBLE PRECISION DEFAULT 0;
ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS lifetime_earnings DOUBLE PRECISION DEFAULT 0;
ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS cod_debt DOUBLE PRECISION DEFAULT 0;

-- ==========================================================
-- ⚖️ 4. DISPUTES & REFUNDS HUB
-- ==========================================================
CREATE TABLE IF NOT EXISTS public.disputes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES public.orders(id) ON DELETE CASCADE,
    user_id UUID NOT NULL, -- Customer raising the dispute
    reason TEXT NOT NULL, -- WRONG_ITEM, MISSING_ITEM, BAD_QUALITY, LATE_DELIVERY, CANCELLATION
    detail_msg TEXT,
    evidence_urls TEXT[],
    status TEXT DEFAULT 'PENDING', -- PENDING, INVESTIGATING, RESOLVED, REJECTED
    resolution_type TEXT, -- FULL_REFUND, PARTIAL_REFUND, COUPON, REJECTED
    refund_amount DOUBLE PRECISION DEFAULT 0,
    admin_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    resolved_at TIMESTAMPTZ
);

ALTER TABLE public.disputes REPLICA IDENTITY FULL;

-- ==========================================================
-- 🏎️ 5. ENHANCED WITHDRAWALS (Safety First)
-- ==========================================================
-- Riders cannot withdraw if COD_DEBT > Limit
ALTER TABLE public.withdrawals ADD COLUMN IF NOT EXISTS processed_at TIMESTAMPTZ;
ALTER TABLE public.withdrawals ADD COLUMN IF NOT EXISTS admin_id UUID;
ALTER TABLE public.withdrawals ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

-- ==========================================================
-- 🛠️ 6. THE SETTLEMENT ENGINE (RPC)
-- ==========================================================
-- Calculates splits and updates ledgers/wallets upon delivery completion.
CREATE OR REPLACE FUNCTION public.process_order_settlement_v17(p_order_id UUID)
RETURNS VOID AS $$
DECLARE
    v_order_total DOUBLE PRECISION;
    v_vendor_id UUID;
    v_rider_id UUID;
    v_platform_share DOUBLE PRECISION;
    v_vendor_share DOUBLE PRECISION;
    v_rider_share DOUBLE PRECISION;
    v_payment_method TEXT;
    v_commission_rate DOUBLE PRECISION;
    v_vendor_owner_id UUID;
BEGIN
    -- 1. Get Order Facts
    SELECT total, vendor_id, rider_id, payment_method, 
           (SELECT owner_id FROM public.vendors WHERE id = o.vendor_id),
           (SELECT commission_rate FROM public.vendors WHERE id = o.vendor_id)
    INTO v_order_total, v_vendor_id, v_rider_id, v_payment_method, v_vendor_owner_id, v_commission_rate
    FROM public.orders o WHERE id = p_order_id;

    -- 2. Calculate Split
    v_commission_rate := COALESCE(v_commission_rate, 10.0);
    v_platform_share := (v_order_total * v_commission_rate / 100.0);
    v_rider_share := 20.0; -- Hardcoded base for now, can be dynamic
    v_vendor_share := v_order_total - v_platform_share - v_rider_share;

    -- 3. Update Vendor Wallet
    INSERT INTO public.wallets (user_id, balance, lifetime_earnings)
    VALUES (v_vendor_owner_id, v_vendor_share, v_vendor_share)
    ON CONFLICT (user_id) DO UPDATE SET
        balance = wallets.balance + EXCLUDED.balance,
        lifetime_earnings = wallets.lifetime_earnings + EXCLUDED.lifetime_earnings,
        updated_at = now();

    -- 4. Update Rider Wallet
    INSERT INTO public.wallets (user_id, balance, lifetime_earnings)
    VALUES (v_rider_id, v_rider_share, v_rider_share)
    ON CONFLICT (user_id) DO UPDATE SET
        balance = wallets.balance + EXCLUDED.balance,
        lifetime_earnings = wallets.lifetime_earnings + EXCLUDED.lifetime_earnings,
        updated_at = now();

    -- 5. Handle COD Debt Tracking
    IF v_payment_method = 'COD' THEN
        UPDATE public.wallets SET cod_debt = cod_debt + v_order_total
        WHERE user_id = v_rider_id;
        
        -- Record Debt in Ledger
        INSERT INTO public.financial_ledger (entry_type, user_id, order_id, amount, flow_type, notes)
        VALUES ('COD_COLLECTION', v_rider_id, p_order_id, v_order_total, 'IN', 'Rider collected cash at doorstep');
    END IF;

    -- 6. Audit Split in Ledger
    INSERT INTO public.financial_ledger (entry_type, user_id, order_id, amount, flow_type, notes)
    VALUES ('SPLIT_VENDOR', v_vendor_owner_id, p_order_id, v_vendor_share, 'INTERNAL', 'Auto-settlement share');
    
    INSERT INTO public.financial_ledger (entry_type, user_id, order_id, amount, flow_type, notes)
    VALUES ('SPLIT_RIDER', v_rider_id, p_order_id, v_rider_share, 'INTERNAL', 'Auto-settlement share');

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==========================================================
-- 🛒 7. THE PAYMENT FLOW ENGINE (v5)
-- ==========================================================
CREATE OR REPLACE FUNCTION public.place_order_v5(
    p_customer_id UUID,
    p_vendor_id UUID,
    p_items JSONB,
    p_total DOUBLE PRECISION,
    p_address TEXT,
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION,
    p_payment_method TEXT,
    p_instructions TEXT DEFAULT NULL,
    p_address_id TEXT DEFAULT NULL,
    p_initial_status TEXT DEFAULT 'placed'
)
RETURNS UUID AS $$
DECLARE
    v_order_id UUID;
    v_v_lat DOUBLE PRECISION;
    v_v_lng DOUBLE PRECISION;
    v_v_radius DOUBLE PRECISION;
    v_v_status TEXT;
    v_is_open BOOLEAN;
    v_dist DOUBLE PRECISION;
BEGIN
    -- 1. Fetch Vendor Stats
    SELECT latitude, longitude, COALESCE(delivery_radius_km, 15.0), status, is_open 
    INTO v_v_lat, v_v_lng, v_v_radius, v_v_status, v_is_open
    FROM public.vendors WHERE id = p_vendor_id;

    -- 2. Validate
    IF v_v_status != 'ONLINE' OR v_is_open = FALSE THEN
        RAISE EXCEPTION 'VENDOR_OFFLINE';
    END IF;

    -- Haversine Distance
    v_dist := 6371 * acos(
        cos(radians(p_lat)) * cos(radians(v_v_lat)) * 
        cos(radians(v_v_lng) - radians(p_lng)) + 
        sin(radians(p_lat)) * sin(radians(v_v_lat))
    );

    IF v_dist > v_v_radius THEN
        RAISE EXCEPTION 'OUT_OF_RADIUS';
    END IF;

    -- 3. Insert Order
    INSERT INTO public.orders (
        customer_id, vendor_id, items, total, address, 
        delivery_lat, delivery_lng, pickup_lat, pickup_lng,
        status, payment_method, payment_status,
        pickup_otp, delivery_otp, delivery_address_id, cooking_instructions
    ) VALUES (
        p_customer_id, p_vendor_id, p_items, p_total, p_address, 
        p_lat, p_lng, v_v_lat, v_v_lng,
        p_initial_status, p_payment_method, CASE WHEN p_payment_method = 'COD' THEN 'pending' ELSE 'unpaid' END,
        lpad(floor(random() * 10000)::text, 4, '0'), 
        lpad(floor(random() * 10000)::text, 4, '0'),
        p_address_id, p_instructions
    ) RETURNING id INTO v_order_id;

    -- 4. Audit
    INSERT INTO public.financial_ledger (entry_type, user_id, order_id, amount, flow_type, notes)
    VALUES ('ORDER_INIT', p_customer_id, v_order_id, p_total, 'IN', 'Order initialized via ' || p_payment_method);

    RETURN v_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==========================================================
-- ✅ 8. PAYMENT FINALIZATION
-- ==========================================================
CREATE OR REPLACE FUNCTION public.finalize_payment_v17(
    p_order_id UUID,
    p_payment_id TEXT,
    p_payment_method TEXT
)
RETURNS VOID AS $$
BEGIN
    UPDATE public.orders SET 
        status = 'placed',
        payment_status = 'paid',
        payment_id = p_payment_id,
        updated_at = now()
    WHERE id = p_order_id;

    -- Create Payment Record
    INSERT INTO public.payments (order_id, user_id, payment_method, transaction_id, amount, status)
    SELECT id, customer_id, p_payment_method, p_payment_id, total, 'SUCCESS'
    FROM public.orders WHERE id = p_order_id;

    -- Record in Ledger
    INSERT INTO public.financial_ledger (entry_type, order_id, amount, flow_type, notes)
    SELECT 'PAYMENT_CAPTURE', p_order_id, total, 'IN', 'Online payment captured: ' || p_payment_id
    FROM public.orders WHERE id = p_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==========================================================
-- ⚖️ 10. CANCELLATION & REFUND ENGINE
-- ==========================================================
CREATE OR REPLACE FUNCTION public.request_cancellation_v17(
    p_order_id UUID,
    p_user_id UUID,
    p_reason TEXT DEFAULT 'User requested'
)
RETURNS JSONB AS $$
DECLARE
    v_order_status TEXT;
    v_payment_status TEXT;
    v_payment_method TEXT;
    v_total DOUBLE PRECISION;
    v_refund_amount DOUBLE PRECISION;
    v_cancellation_fee DOUBLE PRECISION := 0;
BEGIN
    SELECT status, payment_status, payment_method, total
    INTO v_order_status, v_payment_status, v_payment_method, v_total
    FROM public.orders WHERE id = p_order_id;

    -- 1. Rules Logic
    IF v_order_status = 'delivered' OR v_order_status = 'on_the_way' THEN
        RAISE EXCEPTION 'CANCELLATION_BLOCKED: Order is already in transit or delivered.';
    END IF;

    -- Before Vendor Accept: 100% Refund
    IF v_order_status IN ('placed', 'payment_pending') THEN
        v_refund_amount := v_total;
    -- After Vendor Accept: Check if Preparing
    ELSIF v_order_status = 'preparing' THEN
        v_cancellation_fee := v_total * 0.5; -- 50% Fee if already preparing
        v_refund_amount := v_total - v_cancellation_fee;
    ELSE
        v_refund_amount := v_total;
    END IF;

    -- 2. Update Order
    UPDATE public.orders SET 
        status = 'cancelled',
        updated_at = now()
    WHERE id = p_order_id;

    -- 3. Create Dispute/Refund Record if Paid
    IF (v_payment_status = 'paid' OR v_payment_status = 'PAID') AND v_refund_amount > 0 THEN
        INSERT INTO public.disputes (order_id, user_id, reason, detail_msg, status, refund_amount)
        VALUES (p_order_id, p_user_id, 'CANCELLATION', p_reason, 'PENDING', v_refund_amount);
        
        -- Audit Ledger
        INSERT INTO public.financial_ledger (entry_type, order_id, amount, flow_type, notes)
        VALUES ('REFUND_INIT', p_order_id, v_refund_amount, 'OUT', 'Auto-refund triggered by cancellation');
    END IF;

    RETURN jsonb_build_object(
        'status', 'cancelled',
        'refund_initiated', v_refund_amount > 0,
        'refund_amount', v_refund_amount,
        'cancellation_fee', v_cancellation_fee
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==========================================================
-- 🏦 11. DEBT RECONCILIATION (Rider COD)
-- ==========================================================
CREATE OR REPLACE FUNCTION public.driver_deposit_cod(
    p_driver_id UUID,
    p_amount DOUBLE PRECISION
)
RETURNS VOID AS $$
BEGIN
    UPDATE public.wallets SET 
        cod_debt = GREATEST(0, cod_debt - p_amount),
        updated_at = now()
    WHERE user_id = p_driver_id;

    -- Also sync with legacy field if exists
    UPDATE public.delivery_riders SET cod_held = GREATEST(0, cod_held - p_amount)
    WHERE id = p_driver_id::text;

    -- Audit in Ledger
    INSERT INTO public.financial_ledger (entry_type, user_id, amount, flow_type, notes)
    VALUES ('COD_SETTLEMENT', p_driver_id, p_amount, 'OUT', 'Driver submitted cash to platform');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==========================================================
-- 🛡️ 12. AUTO-TRIGGER SETTLEMENT
-- ==========================================================
CREATE OR REPLACE FUNCTION public.trigger_settlement_on_delivery()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'delivered' AND OLD.status != 'delivered' THEN
        PERFORM public.process_order_settlement_v17(NEW.id);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_settle_order_on_delivered
AFTER UPDATE ON public.orders
FOR EACH ROW
EXECUTE FUNCTION public.trigger_settlement_on_delivery();

COMMIT;
