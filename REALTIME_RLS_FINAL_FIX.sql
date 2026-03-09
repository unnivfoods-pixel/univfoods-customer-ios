-- FINAL REALTIME & RLS FIX FOR DELIVERY FLOW
-- Run this in Supabase SQL Editor

-- 1. Ensure rider_tracking table exists for high-freq location history
CREATE TABLE IF NOT EXISTS public.rider_tracking (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at timestamptz DEFAULT now(),
    order_id uuid REFERENCES public.orders(id),
    rider_id uuid REFERENCES public.delivery_riders(id),
    latitude double precision NOT NULL,
    longitude double precision NOT NULL,
    timestamp timestamptz DEFAULT now()
);

-- 1b. Ensure support_tickets table exists
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

-- 2. Expand orders table if missing columns (Safety check)
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS rider_assigned_at timestamptz,
ADD COLUMN IF NOT EXISTS order_picked_up_at timestamptz,
ADD COLUMN IF NOT EXISTS order_delivered_at timestamptz,
ADD COLUMN IF NOT EXISTS pickup_otp text,
ADD COLUMN IF NOT EXISTS delivery_otp text;

-- 3. ENABLE REALTIME FOR ALL CRITICAL TABLES
BEGIN;
  -- Drop if exists to avoid errors on duplicate
  DROP PUBLICATION IF EXISTS supabase_realtime;
  CREATE PUBLICATION supabase_realtime FOR TABLE 
    public.orders, 
    public.delivery_riders, 
    public.rider_tracking, 
    public.support_tickets,
    public.vendors,
    public.customer_profiles;
COMMIT;

-- 4. RLS BYPASS FOR DEMO / DEVELOPMENT
-- This ensures the app works without complex Auth checks during development
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.delivery_riders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rider_tracking ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendors ENABLE ROW LEVEL SECURITY;

-- Dynamic Policies (ALLOW ALL for demo)
DO $$ 
BEGIN
    -- Orders
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Allow all orders' AND tablename = 'orders') THEN
        CREATE POLICY "Allow all orders" ON public.orders FOR ALL USING (true) WITH CHECK (true);
    END IF;
    -- Riders
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Allow all riders' AND tablename = 'delivery_riders') THEN
        CREATE POLICY "Allow all riders" ON public.delivery_riders FOR ALL USING (true) WITH CHECK (true);
    END IF;
    -- Tracking
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Allow all tracking' AND tablename = 'rider_tracking') THEN
        CREATE POLICY "Allow all tracking" ON public.rider_tracking FOR ALL USING (true) WITH CHECK (true);
    END IF;
    -- Support
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Allow all support' AND tablename = 'support_tickets') THEN
        CREATE POLICY "Allow all support" ON public.support_tickets FOR ALL USING (true) WITH CHECK (true);
    END IF;
    -- Vendors
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Allow all vendors' AND tablename = 'vendors') THEN
        CREATE POLICY "Allow all vendors" ON public.vendors FOR ALL USING (true) WITH CHECK (true);
    END IF;
END $$;

-- 5. OTP GENERATION & TRIGGERS
CREATE OR REPLACE FUNCTION generate_otp() RETURNS text AS $$
BEGIN
    RETURN (floor(random() * (9999 - 1000 + 1) + 1000))::text;
END;
$$ LANGUAGE plpgsql;

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

DROP TRIGGER IF EXISTS tr_prepare_order ON public.orders;
CREATE TRIGGER tr_prepare_order
BEFORE INSERT OR UPDATE OF status ON public.orders
FOR EACH ROW
WHEN (NEW.status = 'placed')
EXECUTE FUNCTION prepare_order_delivery();

-- 6. FUNCTION: UPDATE RIDER STATS ON DELIVERY
-- This increments the 'total_rides' in delivery_riders when an order is marked 'delivered'
CREATE OR REPLACE FUNCTION public.increment_rider_stats()
RETURNS TRIGGER AS $$
BEGIN
    IF (NEW.status = 'delivered' AND OLD.status != 'delivered') THEN
        UPDATE public.delivery_riders
        SET total_rides = COALESCE(total_rides, 0) + 1
        WHERE id = NEW.delivery_partner_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_order_delivered_stats ON public.orders;
CREATE TRIGGER tr_order_delivered_stats
AFTER UPDATE ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.increment_rider_stats();

-- 7. NOTIFICATIONS TABLE (For Admin Pulse)
CREATE TABLE IF NOT EXISTS public.notifications (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at timestamptz DEFAULT now(),
    title text NOT NULL,
    body text NOT NULL,
    role text, -- ADMIN, RIDER, VENDOR, CUSTOMER
    is_read boolean DEFAULT false,
    user_id uuid REFERENCES auth.users(id)
);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Allow all notifications' AND tablename = 'notifications') THEN
        CREATE POLICY "Allow all notifications" ON public.notifications FOR ALL USING (true) WITH CHECK (true);
    END IF;
END $$;
