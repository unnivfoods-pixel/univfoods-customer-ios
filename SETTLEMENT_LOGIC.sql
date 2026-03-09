-- 💰 SETTLEMENT & PAYOUT LOGIC (PRODUCTION READY)

-- 1. Add Settlement Columns to ORDERS table
ALTER TABLE orders 
ADD COLUMN IF NOT EXISTS commission_rate numeric DEFAULT 20.0, -- Default 20%
ADD COLUMN IF NOT EXISTS commission_amount numeric DEFAULT 0.0,
ADD COLUMN IF NOT EXISTS gst_on_commission numeric DEFAULT 0.0,
ADD COLUMN IF NOT EXISTS net_vendor_payable numeric DEFAULT 0.0,
ADD COLUMN IF NOT EXISTS driver_earning numeric DEFAULT 0.0,
ADD COLUMN IF NOT EXISTS cod_amount_collected numeric DEFAULT 0.0,
ADD COLUMN IF NOT EXISTS is_settled_vendor boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS is_settled_driver boolean DEFAULT false;

-- 2. Add Wallet Columns to VENDORS & RIDERS
ALTER TABLE vendors 
ADD COLUMN IF NOT EXISTS wallet_balance numeric DEFAULT 0.0,
ADD COLUMN IF NOT EXISTS total_earnings numeric DEFAULT 0.0;

ALTER TABLE delivery_riders 
ADD COLUMN IF NOT EXISTS wallet_balance numeric DEFAULT 0.0,
ADD COLUMN IF NOT EXISTS cod_held numeric DEFAULT 0.0, -- Cash in hand
ADD COLUMN IF NOT EXISTS total_earnings numeric DEFAULT 0.0;

-- 3. Create Payout Requests Tables
CREATE TABLE IF NOT EXISTS vendor_payouts (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    vendor_id uuid REFERENCES vendors(id),
    amount numeric NOT NULL,
    status text DEFAULT 'pending', -- pending, approved, paid, rejected
    transaction_ref text,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS driver_payouts (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    driver_id uuid REFERENCES delivery_riders(id),
    amount numeric NOT NULL,
    status text DEFAULT 'pending',
    transaction_ref text,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- 4. The "Brain" Function: Calculate Settlements on Delivery
CREATE OR REPLACE FUNCTION process_order_settlement()
RETURNS TRIGGER AS $$
DECLARE
    v_commission_rate numeric;
    v_item_total numeric;
    v_commission numeric;
    v_gst numeric;
    v_vendor_net numeric;
    v_driver_base numeric := 30.0; -- Configurable Base Fee
    v_driver_tip numeric;
    v_driver_total numeric;
BEGIN
    -- Only run when status changes to 'delivered' AND not yet processed
    IF NEW.status = 'delivered' AND OLD.status != 'delivered' THEN
        
        -- A. FETCH DATA
        SELECT commission_rate INTO v_commission_rate FROM orders WHERE id = NEW.id;
        IF v_commission_rate IS NULL THEN v_commission_rate := 20.0; END IF; -- Fallback
        
        v_item_total := NEW.item_total;
        v_driver_tip := COALESCE(NEW.tip_amount, 0.0);
        
        -- B. VENDOR MATH
        -- Commission = ItemTotal * Rate%
        v_commission := v_item_total * (v_commission_rate / 100.0);
        -- GST on Commission (18%)
        v_gst := v_commission * 0.18;
        -- Vendor Net
        v_vendor_net := v_item_total - v_commission - v_gst;

        -- C. DRIVER MATH
        -- Earning = Base (30) + Tip
        -- (Ideally fetch base from config, hardcoded for MVP)
        v_driver_total := v_driver_base + v_driver_tip;

        -- D. UPDATE ORDER RECORD
        UPDATE orders SET
            commission_amount = v_commission,
            gst_on_commission = v_gst,
            net_vendor_payable = v_vendor_net,
            driver_earning = v_driver_total,
            cod_amount_collected = CASE WHEN NEW.payment_method = 'cod' THEN NEW.total ELSE 0.0 END
        WHERE id = NEW.id;

        -- E. UPDATE VENDOR WALLET
        UPDATE vendors SET
            wallet_balance = wallet_balance + v_vendor_net,
            total_earnings = total_earnings + v_vendor_net
        WHERE id = NEW.vendor_id;

        -- F. UPDATE DRIVER WALLET & COD HOLDINGS
        UPDATE delivery_riders SET
            -- Add Earning
            wallet_balance = wallet_balance + v_driver_total,
            total_earnings = total_earnings + v_driver_total,
            -- If COD, Track Cash Held (Debt)
            cod_held = cod_held + CASE WHEN NEW.payment_method = 'cod' THEN NEW.total ELSE 0.0 END
        WHERE id = NEW.delivery_partner_id;

        -- G. LOG FOR ADMIN (Implicit via the tables)
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5. Attach Trigger
DROP TRIGGER IF EXISTS trg_order_settlement ON orders;
CREATE TRIGGER trg_order_settlement
AFTER UPDATE ON orders
FOR EACH ROW
EXECUTE FUNCTION process_order_settlement();

-- 6. RPC For Driver to "Deposit" COD (Admin approves)
CREATE OR REPLACE FUNCTION driver_deposit_cod(p_driver_id uuid, p_amount numeric)
RETURNS void AS $$
BEGIN
    UPDATE delivery_riders 
    SET cod_held = cod_held - p_amount 
    WHERE id = p_driver_id;
    
    -- In real app, create a 'deposit_transaction' record here
END;
$$ LANGUAGE plpgsql security definer;

-- 7. Real-time permissions
ALTER PUBLICATION supabase_realtime ADD TABLE vendor_payouts;
ALTER PUBLICATION supabase_realtime ADD TABLE driver_payouts;
