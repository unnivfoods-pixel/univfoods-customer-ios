-- =============================================================================
-- REAL-TIME PAYOUTS & WALLET SYSTEM
-- Targets: Vendors, Riders, and Real-time Earning Feeds
-- =============================================================================

-- 1. Add Wallet Balances to Profiles
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vendors' AND column_name = 'wallet_balance') THEN
        ALTER TABLE "vendors" ADD COLUMN "wallet_balance" numeric DEFAULT 0.0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'delivery_riders' AND column_name = 'wallet_balance') THEN
        ALTER TABLE "delivery_riders" ADD COLUMN "wallet_balance" numeric DEFAULT 0.0;
    END IF;
END $$;

-- 2. Transactions Table (The Real-time Feed)
CREATE TABLE IF NOT EXISTS public.transactions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at timestamp with time zone DEFAULT now(),
    user_id uuid, -- Auth ID or Profile ID
    target_type text, -- 'vendor', 'rider'
    target_id uuid, -- Specific vendor_id or rider_id
    order_id uuid REFERENCES public.orders(id),
    amount numeric NOT NULL,
    type text, -- 'earning', 'payout', 'refund'
    description text,
    status text DEFAULT 'completed'
);

-- 3. Enable Real-time for Transactions
ALTER PUBLICATION supabase_realtime ADD TABLE public.transactions;

-- 4. Payout Processing Function (Dynamic Fees)
CREATE OR REPLACE FUNCTION public.handle_order_completion()
RETURNS TRIGGER AS $$
DECLARE
    vendor_share numeric;
    rider_share numeric;
    config jsonb;
    v_percent numeric;
    r_percent numeric;
BEGIN
    -- Fetch current fee config
    SELECT value INTO config FROM public.app_settings WHERE key = 'delivery_config';
    v_percent := (config->>'vendor_payout_percent')::numeric / 100.0;
    r_percent := (config->>'rider_payout_percent')::numeric / 100.0;

    -- Only process ONCE when status turns 'delivered'
    IF (NEW.status = 'delivered' AND (OLD.status IS NULL OR OLD.status != 'delivered')) THEN
        
        rider_share := NEW.total * r_percent;
        vendor_share := NEW.total * v_percent;

        -- 1. Update Rider Balance
        IF NEW.delivery_partner_id IS NOT NULL THEN
            UPDATE public.delivery_riders 
            SET wallet_balance = wallet_balance + rider_share
            WHERE id = NEW.delivery_partner_id;

            INSERT INTO public.transactions (target_id, target_type, order_id, amount, type, description)
            VALUES (NEW.delivery_partner_id, 'rider', NEW.id, rider_share, 'earning', 'Earning from Delivery Order');
        END IF;

        -- 2. Update Vendor Balance
        IF NEW.vendor_id IS NOT NULL THEN
            UPDATE public.vendors 
            SET wallet_balance = wallet_balance + vendor_share
            WHERE id = NEW.vendor_id;

            INSERT INTO public.transactions (target_id, target_type, order_id, amount, type, description)
            VALUES (NEW.vendor_id, 'vendor', NEW.id, vendor_share, 'earning', 'Payout from Sale');
        END IF;

    END IF;

    -- Handle Refunds
    IF (NEW.payment_status = 'refunded' AND (OLD.payment_status IS NULL OR OLD.payment_status != 'refunded')) THEN
        -- Log refund transaction
        INSERT INTO public.transactions (user_id, order_id, amount, type, description)
        VALUES (NEW.user_id, NEW.id, -NEW.total, 'refund', 'Order Refunded');
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5. Attach Trigger to Orders
DROP TRIGGER IF EXISTS on_order_payout_trigger ON public.orders;
CREATE TRIGGER on_order_payout_trigger
AFTER UPDATE ON public.orders
FOR EACH ROW EXECUTE PROCEDURE public.handle_order_completion();

-- 6. Permissions
GRANT ALL ON TABLE public.transactions TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.vendors TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.delivery_riders TO anon, authenticated, service_role;

-- 7. Seed App Settings for Fees
INSERT INTO public.app_settings (key, value)
VALUES ('delivery_config', '{"max_radius_km": 15, "min_order_value": 0, "vendor_payout_percent": 80, "rider_payout_percent": 15}'::jsonb)
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
