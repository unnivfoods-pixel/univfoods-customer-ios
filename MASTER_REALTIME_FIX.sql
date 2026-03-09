-- 🚨 GRAND MASTER REALTIME & RELATIONSHIP FIX (Play Store Ready VERSION)
-- Run this in Supabase SQL Editor to fix ALL disconnects

-- 1. BASE TABLES CHECK & REPAIR
-- Ensure foreign keys are explicit and names match app expectations

-- Fix delivery_riders table if schema name is mismatched
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'delivery_riders') THEN
        CREATE TABLE public.delivery_riders (
            id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
            user_id uuid REFERENCES auth.users(id),
            name text,
            phone text,
            status text DEFAULT 'offline',
            is_online boolean DEFAULT false,
            is_approved boolean DEFAULT false,
            current_lat double precision,
            current_lng double precision,
            last_location_update timestamptz DEFAULT now(),
            created_at timestamptz DEFAULT now()
        );
    END IF;
END $$;

-- 2. FORCE REPLICA IDENTITY (The Realtime Secret)
-- Without this, UPDATE events only send the primary key, breaking UI updates
ALTER TABLE public.orders REPLICA IDENTITY FULL;
ALTER TABLE public.delivery_riders REPLICA IDENTITY FULL;
ALTER TABLE public.vendors REPLICA IDENTITY FULL;
ALTER TABLE public.notifications REPLICA IDENTITY FULL;

-- 3. RE-CREATE PUBLICATION (Nuclear Option)
-- This ensures Supabase actually broadcasts changes to the apps
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR TABLE 
    public.orders, 
    public.delivery_riders, 
    public.vendors, 
    public.rider_tracking, 
    public.support_tickets,
    public.notifications,
    public.products;

-- 4. FIX RELATIONSHIP NAMES for PostgREST (Admin App expects these)
-- Explicitly naming the foreign keys helps the .select('*, vendors(...)') syntax
ALTER TABLE public.orders 
DROP CONSTRAINT IF EXISTS orders_vendor_id_fkey,
ADD CONSTRAINT orders_vendor_id_fkey 
FOREIGN KEY (vendor_id) REFERENCES public.vendors(id) ON DELETE SET NULL;

ALTER TABLE public.orders 
DROP CONSTRAINT IF EXISTS orders_delivery_partner_id_fkey,
ADD CONSTRAINT orders_delivery_partner_id_fkey 
FOREIGN KEY (delivery_partner_id) REFERENCES public.delivery_riders(id) ON DELETE SET NULL;

ALTER TABLE public.orders 
DROP CONSTRAINT IF EXISTS orders_customer_id_fkey,
ADD CONSTRAINT orders_customer_id_fkey 
FOREIGN KEY (customer_id) REFERENCES auth.users(id) ON DELETE SET NULL;

-- 5. RE-INITIALIZE NOTIFICATIONS FOR APPS
-- Ensure notifications table is broadcast-ready for the Admin Pulse
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access to notifications" ON public.notifications;
CREATE POLICY "Public access to notifications" ON public.notifications FOR ALL USING (true);

-- 6. ADD ORDER STATUS LOGGING (For Debugging Admin)
CREATE OR REPLACE FUNCTION log_order_update()
RETURNS TRIGGER AS $$
BEGIN
    IF (OLD.status IS DISTINCT FROM NEW.status) THEN
        INSERT INTO public.notifications (title, body, role, user_id)
        VALUES (
            'Order Update',
            'Order #' || LEFT(NEW.id::text, 8) || ' changed from ' || OLD.status || ' to ' || NEW.status,
            'ADMIN',
            NULL
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_log_status_change ON public.orders;
CREATE TRIGGER tr_log_status_change
AFTER UPDATE ON public.orders
FOR EACH ROW EXECUTE FUNCTION log_order_update();

-- 7. CLEAN UP ZOMBIE REALTIME SLOTS
-- Sometimes too many open channels block new ones
SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE usename = 'supabase_admin';
