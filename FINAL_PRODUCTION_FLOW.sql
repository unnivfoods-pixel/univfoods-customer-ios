-- 🚀 FINAL PRODUCTION FLOW: PIN-TO-PIN SYSTEM
-- 🧾 1. PAYMENT & ESCROW ENGINE
-- 💸 2. REFUND & FINANCIALS
-- 📍 3. REALTIME LOGISTICS & TRACKING

-- [1] EXTENDED ORDER INFRASTRUCTURE
-- (Point 1.1: Lock address, Lock cart, Calculate payable)
DO $$
BEGIN
    -- Add OTP columns
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'pickup_otp') THEN
        ALTER TABLE public.orders ADD COLUMN "pickup_otp" TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'delivery_otp') THEN
        ALTER TABLE public.orders ADD COLUMN "delivery_otp" TEXT;
    END IF;

    -- Add Detailed Payment State
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'payment_state') THEN
        ALTER TABLE public.orders ADD COLUMN "payment_state" TEXT DEFAULT 'PENDING_INTENT';
    END IF;

    -- Add Billing Breakdown Columns (Locked Snapshot)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'bill_details') THEN
        ALTER TABLE public.orders ADD COLUMN "bill_details" JSONB DEFAULT '{}'::jsonb;
    END IF;
END $$;

-- (Point 3.B: Order Items Table)
CREATE TABLE IF NOT EXISTS public.order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id UUID, 
    name TEXT NOT NULL,
    quantity INTEGER NOT NULL,
    price_at_order NUMERIC NOT NULL,
    subtotal NUMERIC NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- (Point 1, Step 2: Payment Intent Table - Escrow/Temp)
CREATE TABLE IF NOT EXISTS public.payment_intents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID REFERENCES auth.users(id),
    vendor_id UUID REFERENCES public.vendors(id),
    amount NUMERIC NOT NULL,
    cart_snapshot JSONB NOT NULL,
    delivery_address JSONB NOT NULL,
    status TEXT DEFAULT 'pending', -- 'pending', 'succeeded', 'failed'
    payment_method TEXT DEFAULT 'online',
    gateway_txn_id TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- settlements (Point 5 - Settlement calculated)
CREATE TABLE IF NOT EXISTS public.settlements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES public.orders(id),
    vendor_id UUID REFERENCES public.vendors(id),
    rider_id UUID REFERENCES public.delivery_riders(id),
    order_total NUMERIC,
    vendor_share NUMERIC,
    rider_share NUMERIC,
    platform_commission NUMERIC,
    status TEXT DEFAULT 'pending', -- 'pending', 'settled'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- [2] FINANCIAL LOGIC (RPCs)

-- create_payment_intent: Locks cart and returns ID
CREATE OR REPLACE FUNCTION public.create_payment_intent(
    p_vendor_id UUID,
    p_amount NUMERIC,
    p_cart JSONB,
    p_address JSONB,
    p_method TEXT
) RETURNS UUID AS $$
DECLARE
    v_intent_id UUID;
BEGIN
    INSERT INTO public.payment_intents (customer_id, vendor_id, amount, cart_snapshot, delivery_address, payment_method)
    VALUES (auth.uid(), p_vendor_id, p_amount, p_cart, p_address, p_method)
    RETURNING id INTO v_intent_id;
    
    RETURN v_intent_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- verify_and_create_order: Webhook equivalent (Simulation)
CREATE OR REPLACE FUNCTION public.verify_and_create_order(p_intent_id UUID, p_gateway_id TEXT)
RETURNS UUID AS $$
DECLARE
    v_intent RECORD;
    v_order_id UUID;
    v_pickup_otp TEXT;
    v_delivery_otp TEXT;
BEGIN
    -- 1. Get Intent
    SELECT * INTO v_intent FROM public.payment_intents WHERE id = p_intent_id AND (status = 'pending' OR status = 'temp');
    IF NOT FOUND THEN RETURN NULL; END IF;

    -- 2. Update Intent
    UPDATE public.payment_intents SET status = 'succeeded', gateway_txn_id = p_gateway_id WHERE id = p_intent_id;

    -- 3. Generate OTPs (Rule 5: OTP Mandatory)
    v_pickup_otp := floor(random() * 9000 + 1000)::text;
    v_delivery_otp := floor(random() * 9000 + 1000)::text;

    -- 4. Create actual order record (Rule: ONLY after verification)
    INSERT INTO public.orders (
        customer_id, vendor_id, total, status, payment_method, payment_state, 
        items, delivery_lat, delivery_lng, bill_details, pickup_otp, delivery_otp
    )
    VALUES (
        v_intent.customer_id, 
        v_intent.vendor_id, 
        v_intent.amount, 
        'placed', 
        v_intent.payment_method, 
        CASE WHEN v_intent.payment_method = 'online' THEN 'PAID' ELSE 'COD_PENDING' END,
        v_intent.cart_snapshot, 
        (v_intent.delivery_address->>'lat')::double precision,
        (v_intent.delivery_address->>'lng')::double precision,
        v_intent.cart_snapshot,
        v_pickup_otp,
        v_delivery_otp
    )
    RETURNING id INTO v_order_id;

    RETURN v_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- process_refund (Logic 2: Refund Logic)
CREATE OR REPLACE FUNCTION public.process_refund(p_order_id UUID, p_reason TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    v_order RECORD;
BEGIN
    SELECT * INTO v_order FROM public.orders WHERE id = p_order_id;
    
    -- RULE: Refund only if Placed or Accepted
    IF v_order.status NOT IN ('placed', 'accepted') THEN
        RETURN FALSE;
    END IF;

    UPDATE public.orders 
    SET status = 'cancelled', 
        payment_state = 'REFUND_COMPLETED',
        cancellation_reason = p_reason
    WHERE id = p_order_id;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- [4] SETTLEMENT LOGIC (Point 5)
CREATE OR REPLACE FUNCTION public.calculate_settlement()
RETURNS TRIGGER AS $$
DECLARE
    v_vendor_share NUMERIC;
    v_rider_share NUMERIC;
    v_total NUMERIC;
BEGIN
    IF NEW.status = 'delivered' AND OLD.status != 'delivered' THEN
        v_total := NEW.total;
        -- Mock Split: 85% Vendor, Rs. 40 Rider, Balance Platform
        v_vendor_share := v_total * 0.85;
        v_rider_share := 40.0; 
        
        INSERT INTO public.settlements (
            order_id, vendor_id, rider_id, order_total, 
            vendor_share, rider_share, platform_commission
        )
        VALUES (
            NEW.id, NEW.vendor_id, NEW.rider_id, v_total, 
            v_vendor_share, v_rider_share, (v_total - v_vendor_share - v_rider_share)
        );
        
        -- Update Balances (Financial Engine Rule 5)
        UPDATE public.vendors 
        SET wallet_balance = COALESCE(wallet_balance, 0) + v_vendor_share,
            total_earnings = COALESCE(total_earnings, 0) + v_vendor_share 
        WHERE id = NEW.vendor_id;
        
        UPDATE public.delivery_riders 
        SET wallet_balance = COALESCE(wallet_balance, 0) + v_rider_share,
            total_earnings = COALESCE(total_earnings, 0) + v_rider_share 
        WHERE id = NEW.rider_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_calculate_settlement ON public.orders;
CREATE TRIGGER tr_calculate_settlement
AFTER UPDATE OF status ON public.orders
FOR EACH ROW
EXECUTE FUNCTION public.calculate_settlement();

-- [5] REALTIME PERMISSIONS & TRACKING
DO $$
BEGIN
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.order_items; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.payment_intents; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.settlements; EXCEPTION WHEN OTHERS THEN NULL; END;
END $$;

-- [6] HELPER VIEWS FOR APPS
CREATE OR REPLACE VIEW public.view_customer_orders AS
SELECT 
    o.*,
    v.name as vendor_name,
    v.logo_url as vendor_logo,
    v.address as vendor_address,
    v.lat as pickup_lat,
    v.lng as pickup_lng,
    dr.name as rider_name,
    dr.phone as rider_phone,
    dr.vehicle_number as rider_vehicle,
    dr.current_lat as rider_lat,
    dr.current_lng as rider_lng
FROM public.orders o
JOIN public.vendors v ON o.vendor_id = v.id
LEFT JOIN public.delivery_riders dr ON o.rider_id = dr.id;

ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
GRANT SELECT ON public.view_customer_orders TO anon, authenticated;
