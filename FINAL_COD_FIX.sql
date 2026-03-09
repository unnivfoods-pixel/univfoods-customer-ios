-- 👑 THE FINAL COD & DATABASE SYNC (Critical Fix)
-- Resolves: "record new has no field cash_to_collect"

-- 1. ADD MISSING COLUMNS TO ORDERS TABLE
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS cash_to_collect numeric DEFAULT 0,
ADD COLUMN IF NOT EXISTS pickup_otp text,
ADD COLUMN IF NOT EXISTS delivery_otp text,
ADD COLUMN IF NOT EXISTS payment_state text DEFAULT 'PENDING',
ADD COLUMN IF NOT EXISTS total_amount numeric DEFAULT 0; -- Fallback for some apps

-- 2. REPAIR THE OTP & COD TRIGGER
CREATE OR REPLACE FUNCTION public.prepare_order_delivery()
RETURNS TRIGGER AS $$
BEGIN
    -- 1. Auto-generate OTPs if they are null
    IF NEW.pickup_otp IS NULL THEN
        NEW.pickup_otp := (floor(random() * (9999 - 1000 + 1) + 1000))::text;
    END IF;
    
    IF NEW.delivery_otp IS NULL THEN
        NEW.delivery_otp := (floor(random() * (9999 - 1000 + 1) + 1000))::text;
    END IF;

    -- 2. Sync total/total_amount
    IF NEW.total IS NOT NULL AND NEW.total_amount = 0 THEN
        NEW.total_amount := NEW.total;
    END IF;

    -- 3. Set cash_to_collect for COD orders
    IF NEW.payment_method = 'cod' THEN
        NEW.cash_to_collect := COALESCE(NEW.total, NEW.total_amount, 0);
        NEW.payment_state := 'COD_PENDING';
    ELSE
        NEW.cash_to_collect := 0;
        -- Online payments wait for webhook to move to PAID
        IF NEW.payment_state IS NULL OR NEW.payment_state = 'PENDING' THEN
            NEW.payment_state := 'PENDING';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. RE-BIND TRIGGER
DROP TRIGGER IF EXISTS tr_prepare_order ON public.orders;
CREATE TRIGGER tr_prepare_order
BEFORE INSERT ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.prepare_order_delivery();

-- 4. FIX REALTIME VISIBILITY (Ensure Admin panel sees updates)
ALTER TABLE public.orders REPLICA IDENTITY FULL;
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR TABLE public.orders, public.vendors, public.delivery_riders, public.notifications;
