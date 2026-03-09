-- 🗺️ SUPREME REALTIME & LOGISTICS ENGINE (Play Store Release Version)
-- FIXES: Admin-Rider Connection, Vendor Accepting Logic, Realtime Persistence

-- 1. BASE TABLES REPAIR
ALTER TABLE public.delivery_riders 
ADD COLUMN IF NOT EXISTS is_on_duty boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS total_rides integer DEFAULT 0;

-- 2. STRENGTHEN RELATIONSHIPS
-- This ensures 'select (*, vendors(*))' works perfectly in Admin/Apps
ALTER TABLE public.orders 
DROP CONSTRAINT IF EXISTS orders_vendor_id_fkey CASCADE,
ADD CONSTRAINT orders_vendor_id_fkey 
FOREIGN KEY (vendor_id) REFERENCES public.vendors(id) ON DELETE SET NULL;

ALTER TABLE public.orders 
DROP CONSTRAINT IF EXISTS orders_delivery_partner_id_fkey CASCADE,
ADD CONSTRAINT orders_delivery_partner_id_fkey 
FOREIGN KEY (delivery_partner_id) REFERENCES public.delivery_riders(id) ON DELETE SET NULL;

-- 3. FORCE REPLICA IDENTITY FULL (CRITICAL FOR REALTIME UPDATES)
-- Without this, Supabase only sends IDs for updates, making UI stay stale
ALTER TABLE public.orders REPLICA IDENTITY FULL;
ALTER TABLE public.delivery_riders REPLICA IDENTITY FULL;
ALTER TABLE public.vendors REPLICA IDENTITY FULL;
ALTER TABLE public.customer_profiles REPLICA IDENTITY FULL;
ALTER TABLE public.products REPLICA IDENTITY FULL;

-- 4. RE-SYNC SUPABASE REALTIME PUBLICATION
-- Deletes and Recreates to avoid "Publication already exists" errors
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR TABLE 
    public.orders, 
    public.delivery_riders, 
    public.vendors, 
    public.customer_profiles,
    public.notifications,
    public.rider_tracking,
    public.support_tickets;

-- 5. LOGISTICS AUTOMATION (DEMO PRO MODE)
-- Automatically notify a rider when a vendor accepts an order
CREATE OR REPLACE FUNCTION notify_rider_on_acceptance()
RETURNS TRIGGER AS $$
BEGIN
    IF (NEW.status = 'accepted' AND OLD.status = 'placed') THEN
        INSERT INTO public.notifications (title, body, role, user_id)
        VALUES (
            'New Delivery Available!',
            'Vendor has accepted Order #' || LEFT(NEW.id::text, 8) || '. You can now accept it.',
            'DELIVERY',
            NULL -- Send to all online riders
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_notify_rider_acceptance ON public.orders;
CREATE TRIGGER tr_notify_rider_acceptance
AFTER UPDATE ON public.orders
FOR EACH ROW EXECUTE FUNCTION notify_rider_on_acceptance();

-- 6. ENSURE RLS DOES NOT BLOCK ADMIN (DEMO SAFETY)
-- Allows Admin panel to read all linked data for the Order Dashboard
DROP POLICY IF EXISTS "Admin can read everything" ON public.delivery_riders;
CREATE POLICY "Admin can read everything" ON public.delivery_riders FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admin can read vendors" ON public.vendors;
CREATE POLICY "Admin can read vendors" ON public.vendors FOR SELECT USING (true);

-- 7. INDEXES FOR SPEED ⚡
CREATE INDEX IF NOT EXISTS idx_order_partner_status ON public.orders(delivery_partner_id, status);
CREATE INDEX IF NOT EXISTS idx_rider_online_status ON public.delivery_riders(is_on_duty, is_approved);
