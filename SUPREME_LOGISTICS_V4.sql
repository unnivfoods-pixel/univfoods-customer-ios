-- 🛰️ SUPREME LOGISTICS & FINANCIAL ENGINE V4
-- "The Zero-Leak Protocol": Atomic Wallet Splits, GPS Lockdown, and Fraud Prevention

BEGIN;

-- 1. EXTENDED INFRASTRUCTURE REPAIR
-- -----------------------------------------------------------------------------------
ALTER TABLE public.delivery_riders 
ADD COLUMN IF NOT EXISTS cod_held numeric DEFAULT 0.0,
ADD COLUMN IF NOT EXISTS current_lat numeric,
ADD COLUMN IF NOT EXISTS current_lng numeric,
ADD COLUMN IF NOT EXISTS last_gps_update timestamptz DEFAULT now(),
ADD COLUMN IF NOT EXISTS is_online boolean DEFAULT false;

ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS delivery_otp text,
ADD COLUMN IF NOT EXISTS pickup_otp text,
ADD COLUMN IF NOT EXISTS delivery_lat numeric,
ADD COLUMN IF NOT EXISTS delivery_long numeric,
ADD COLUMN IF NOT EXISTS vendor_payout numeric DEFAULT 0.0,
ADD COLUMN IF NOT EXISTS rider_payout numeric DEFAULT 0.0,
ADD COLUMN IF NOT EXISTS platform_commission numeric DEFAULT 0.0;

-- 2. THE ATOMIC DELIVERY TRIAD (Trigger)
-- This handles the instant split of funds when an order is marked DELIVERED
-- Checks: OTP verification & GPS proximity should be handled by the App/RPC.
CREATE OR REPLACE FUNCTION finalize_mission_financials()
RETURNS TRIGGER AS $$
DECLARE
    v_vendor_share numeric;
    v_rider_share numeric;
    v_platform_share numeric;
    v_commission_rate numeric;
BEGIN
    -- Only trigger on successful DELIVERY
    IF (NEW.status = 'delivered' AND OLD.status != 'delivered') THEN
        
        -- 1. Calculate Payouts
        -- Example Logic: Vendor gets 85%, Platform gets 15%, Rider gets flat fee + bonus
        SELECT (commission_rate/100.0) INTO v_commission_rate FROM public.vendors WHERE id = NEW.vendor_id;
        v_commission_rate := COALESCE(v_commission_rate, 0.15); 
        
        v_platform_share := NEW.total * v_commission_rate;
        v_vendor_share := NEW.total - v_platform_share;
        v_rider_share := 40 + (NEW.total * 0.05); -- ₹40 base + 5% bonus

        NEW.vendor_payout := v_vendor_share;
        NEW.rider_payout := v_rider_share;
        NEW.platform_commission := v_platform_share;

        -- 2. THE SPLIT PROTOCOL
        -- A. ADD EARNINGS TO RIDER WALLET
        INSERT INTO public.wallets (user_id, role, balance)
        VALUES (NEW.delivery_partner_id, 'RIDER', v_rider_share)
        ON CONFLICT (user_id, role) DO UPDATE 
        SET balance = wallets.balance + v_rider_share, updated_at = now();

        -- B. ADD EARNINGS TO VENDOR WALLET
        INSERT INTO public.wallets (user_id, role, balance)
        VALUES (NEW.vendor_id, 'VENDOR', v_vendor_share)
        ON CONFLICT (user_id, role) DO UPDATE 
        SET balance = wallets.balance + v_vendor_share, updated_at = now();

        -- C. HANDLE COD DEBT (If applicable)
        IF (NEW.payment_method = 'COD') THEN
            UPDATE public.delivery_riders 
            SET cod_held = COALESCE(cod_held, 0) + NEW.total 
            WHERE id = NEW.delivery_partner_id;
            
            NEW.payment_state := 'COD_HELD_BY_RIDER';
            
            -- Notify Rider of Debt
            INSERT INTO public.notifications (user_id, title, message, type)
            VALUES (NEW.delivery_partner_id, '🚨 COD DEBT ADDED', 'You collected ₹' || NEW.total || ' in cash. Clear this to enable bank dispatch.', 'FINANCIAL');
        ELSE
            NEW.payment_state := 'PAID_SUCCESS';
        END IF;

        -- Notify Vendor
        INSERT INTO public.notifications (user_id, title, message, type)
        VALUES (NEW.vendor_id, '💰 MISSION COMPLETED', '₹' || v_vendor_share || ' added to your vault for Order #' || NEW.id, 'FINANCIAL');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_finalize_mission ON public.orders;
CREATE TRIGGER tr_finalize_mission
BEFORE UPDATE OF status ON public.orders
FOR EACH ROW EXECUTE FUNCTION finalize_mission_financials();

-- 3. MISSION DISPATCH CONTROL (RPC)
-- Verified completion with GPS and OTP proximity
CREATE OR REPLACE FUNCTION complete_delivery_mission(
    p_order_id uuid,
    p_rider_id uuid,
    p_otp text,
    p_lat numeric,
    p_lng numeric
) RETURNS text AS $$
DECLARE
    v_correct_otp text;
    v_order_lat numeric;
    v_order_lng numeric;
    v_distance numeric;
BEGIN
    -- 1. Identity & State Check
    SELECT delivery_otp, delivery_lat, delivery_long INTO v_correct_otp, v_order_lat, v_order_lng 
    FROM public.orders WHERE id = p_order_id AND delivery_partner_id = p_rider_id AND status = 'on_the_way';

    IF NOT FOUND THEN RETURN 'MISSION_NOT_FOUND_OR_INVALID_STATE'; END IF;

    -- 2. OTP Check
    IF (v_correct_otp != p_otp) THEN RETURN 'INVALID_OTP'; END IF;

    -- 3. GPS Safety Check (Rider must be within ~200m of customer)
    -- Simple bounding box check for demo, can use ST_Distance for prod
    IF (ABS(v_order_lat - p_lat) > 0.005 OR ABS(v_order_lng - p_lng) > 0.005) THEN
        RETURN 'PROXIMITY_ERROR: NOT AT CUSTOMER LOCATION';
    END IF;

    -- 4. Finalize
    UPDATE public.orders SET status = 'delivered', completed_at = now() WHERE id = p_order_id;
    
    -- Clear Rider Active ID
    UPDATE public.delivery_riders SET active_order_id = NULL WHERE id = p_rider_id;

    RETURN 'MISSION_ACCOMPLISHED';
END;
$$ LANGUAGE plpgsql security definer;

-- 4. WITHDRAWAL LOCKDOWN (RPC)
CREATE OR REPLACE FUNCTION request_bank_dispatch(
    p_user_id uuid,
    p_role text,
    p_amount numeric
) RETURNS text AS $$
DECLARE
    v_balance numeric;
    v_cod_debt numeric;
BEGIN
    -- 1. Fetch Financial Vitals
    SELECT balance INTO v_balance FROM public.wallets WHERE user_id = p_user_id AND role = p_role;
    
    -- 2. Debt Check for Riders
    IF (p_role = 'RIDER') THEN
        SELECT cod_held INTO v_cod_debt FROM public.delivery_riders WHERE id = p_user_id;
        IF (v_cod_debt > 0) THEN RETURN 'BLOCK: COD_DEBT_ACTIVE'; END IF;
    END IF;

    -- 3. Min Amount Check
    IF (p_amount < 500) THEN RETURN 'BLOCK: MINIMUM_500_REQUIRED'; END IF;

    -- 4. Balance Check
    IF (v_balance < p_amount) THEN RETURN 'BLOCK: INSUFFICIENT_FUNDS'; END IF;

    -- 5. Create Settlement (Trigger handles the lock)
    INSERT INTO public.settlements (entity_id, role, amount, status)
    VALUES (p_user_id, p_role, p_amount, 'pending');

    RETURN 'REQUEST_INITIATED';
END;
$$ LANGUAGE plpgsql security definer;

-- 5. REAL-TIME REGISTRY UPDATE
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
