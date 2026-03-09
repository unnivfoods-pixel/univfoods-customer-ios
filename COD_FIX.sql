-- 🛠️ COD TRIGGER & COLUMN REPAIR
-- This fixes the "no field cash_to_collect" error

-- 1. Ensure the column exists in public.orders
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS cash_to_collect numeric DEFAULT 0;

-- 2. Repair the prepare_order_delivery function
-- This function runs BEFORE INSERT to setup OTPs and COD amounts
CREATE OR REPLACE FUNCTION public.prepare_order_delivery()
RETURNS TRIGGER AS $$
BEGIN
    -- Generate OTPs if they are missing
    IF NEW.pickup_otp IS NULL THEN
        NEW.pickup_otp := (floor(random() * (9999 - 1000 + 1) + 1000))::text;
    END IF;
    
    IF NEW.delivery_otp IS NULL THEN
        NEW.delivery_otp := (floor(random() * (9999 - 1000 + 1) + 1000))::text;
    END IF;

    -- Set cash_to_collect only if it's a COD order
    IF NEW.payment_method = 'cod' THEN
        NEW.cash_to_collect := NEW.total;
        -- Also initialize payment_state for COD
        NEW.payment_state := 'COD_PENDING';
    ELSE
        -- For online payments, it starts as PENDING until webhook hits
        NEW.cash_to_collect := 0;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Re-bind the trigger to ensure it's active
DROP TRIGGER IF EXISTS tr_prepare_order ON public.orders;
CREATE TRIGGER tr_prepare_order
BEFORE INSERT ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.prepare_order_delivery();

-- 4. Audit: Check for other missing columns that might cause similar errors later
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS pickup_otp text,
ADD COLUMN IF NOT EXISTS delivery_otp text,
ADD COLUMN IF NOT EXISTS payment_state text DEFAULT 'PENDING';
