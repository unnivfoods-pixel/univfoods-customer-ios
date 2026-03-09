-- 🚚 COMPLETE DELIVERY SYSTEM SETUP (DATABASE LAYER)
-- This script adds missing columns and logic to support the end-to-end flow.

-- 1. Expand RIDERS Table for KYC & Banking
ALTER TABLE public.delivery_riders 
ADD COLUMN IF NOT EXISTS kyc_status text DEFAULT 'PENDING', -- PENDING, APPROVED, REJECTED
ADD COLUMN IF NOT EXISTS vehicle_type text DEFAULT 'bike',
ADD COLUMN IF NOT EXISTS vehicle_number text,
ADD COLUMN IF NOT EXISTS bank_account_number text,
ADD COLUMN IF NOT EXISTS bank_ifsc text,
ADD COLUMN IF NOT EXISTS upi_id text,
ADD COLUMN IF NOT EXISTS is_on_duty boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS active_order_id uuid REFERENCES public.orders(id),
ADD COLUMN IF NOT EXISTS last_location_update timestamptz DEFAULT now();

-- 2. Expand ORDERS Table for OTP & Timestamps
ALTER TABLE public.orders
ADD COLUMN IF NOT EXISTS pickup_otp text,
ADD COLUMN IF NOT EXISTS delivery_otp text,
ADD COLUMN IF NOT EXISTS order_ready_at timestamptz,
ADD COLUMN IF NOT EXISTS rider_assigned_at timestamptz,
ADD COLUMN IF NOT EXISTS rider_arrival_at_vendor timestamptz,
ADD COLUMN IF NOT EXISTS order_picked_up_at timestamptz,
ADD COLUMN IF NOT EXISTS order_delivered_at timestamptz,
ADD COLUMN IF NOT EXISTS cash_to_collect numeric DEFAULT 0,
ADD COLUMN IF NOT EXISTS cancellation_reason text;

-- 3. Create SUPPORT TICKETS Table
CREATE TABLE IF NOT EXISTS public.support_tickets (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    user_id uuid REFERENCES auth.users(id),
    role text, -- CUSTOMER, VENDOR, RIDER
    order_id uuid REFERENCES public.orders(id),
    issue_type text,
    description text,
    status text DEFAULT 'OPEN', -- OPEN, IN_PROGRESS, RESOLVED, CLOSED
    priority text DEFAULT 'MEDIUM'
);

-- 4. Function to Generate OTPs
CREATE OR REPLACE FUNCTION generate_otp() RETURNS text AS $$
BEGIN
    RETURN (floor(random() * (9999 - 1000 + 1) + 1000))::text;
END;
$$ LANGUAGE plpgsql;

-- 5. Trigger to set OTPs on order creation or assignment
CREATE OR REPLACE FUNCTION prepare_order_delivery()
RETURNS TRIGGER AS $$
BEGIN
    -- Set OTPs if they don't exist
    IF NEW.pickup_otp IS NULL THEN
        NEW.pickup_otp := generate_otp();
    END IF;
    IF NEW.delivery_otp IS NULL THEN
        NEW.delivery_otp := generate_otp();
    END IF;
    
    -- Set cash to collect for COD
    IF NEW.payment_method = 'cod' THEN
        NEW.cash_to_collect := NEW.total;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_prepare_order_delivery ON public.orders;
CREATE TRIGGER trg_prepare_order_delivery
BEFORE INSERT OR UPDATE OF delivery_partner_id ON public.orders
FOR EACH ROW
EXECUTE FUNCTION prepare_order_delivery();

-- 6. RPC to Update Rider Location and check-in
CREATE OR REPLACE FUNCTION update_rider_location(p_rider_id uuid, p_lat double precision, p_lng double precision, p_heading double precision DEFAULT 0)
RETURNS void AS $$
BEGIN
    UPDATE public.delivery_riders 
    SET current_lat = p_lat, 
        current_lng = p_lng, 
        heading = p_heading,
        last_location_update = now()
    WHERE id = p_rider_id;
END;
$$ LANGUAGE plpgsql security definer;

-- 7. Enable Realtime for Support Tickets
ALTER PUBLICATION supabase_realtime ADD TABLE support_tickets;

-- 8. Add some dummy help topics/FAQ if needed (optional)
-- (Skipping for now to focus on logic)
