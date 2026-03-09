-- 🚨 EMERGENCY LOGISTICS RECOVERY v63 (ULTIMATE REPAIR)
-- 1. Unlock views
-- 2. Ensure snapshot columns exist (customer_name, etc)
-- 3. Fix user_id column type to TEXT
-- 4. Recreate views with safety COALESCE

BEGIN;

-- A. DROP BLOCKING VIEWS
DROP VIEW IF EXISTS public.order_details_v3 CASCADE;
DROP VIEW IF EXISTS public.order_details_v2 CASCADE;
DROP VIEW IF EXISTS public.order_details_v1 CASCADE;

-- B. INFRASTRUCTURE REPAIR (Adding missing snapshot columns first)
DO $$ 
BEGIN
    -- 1. Ensure Orders has snapshot columns (Prevents "column does not exist" error)
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS customer_name TEXT;
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS customer_phone TEXT;
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_address TEXT;
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_lat DOUBLE PRECISION;
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_lng DOUBLE PRECISION;
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS vendor_lat DOUBLE PRECISION;
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS vendor_lng DOUBLE PRECISION;
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS rider_lat DOUBLE PRECISION;
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS rider_lng DOUBLE PRECISION;
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS rider_last_seen TIMESTAMPTZ;
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS estimated_arrival_time TEXT DEFAULT 'Calculating...';
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS assigned_at TIMESTAMPTZ;
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS pickup_time TIMESTAMPTZ;
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMPTZ;
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ;
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS cooking_instructions TEXT;

    -- 2. Notifications table sync
    ALTER TABLE public.notifications ALTER COLUMN user_id TYPE TEXT;
    ALTER TABLE public.notifications ALTER COLUMN order_id TYPE TEXT;
    
    -- 3. Orders identity sync
    ALTER TABLE public.orders ALTER COLUMN customer_id TYPE TEXT;
    ALTER TABLE public.orders ALTER COLUMN status TYPE TEXT;
END $$;

-- C. RECREATE VIEW (v3 Universal Truth)
CREATE VIEW public.order_details_v3 AS
SELECT 
    o.id as order_id,
    o.customer_id,
    o.vendor_id,
    o.rider_id,
    o.items,
    o.total,
    o.status,
    o.payment_method,
    o.payment_status,
    COALESCE(o.delivery_address, 'No Address Provided') as delivery_address,
    o.delivery_lat,
    o.delivery_lng,
    o.vendor_lat,
    o.vendor_lng,
    o.rider_lat,
    o.rider_lng,
    o.rider_last_seen,
    o.estimated_arrival_time,
    o.cooking_instructions,
    o.created_at,
    o.assigned_at,
    o.pickup_time,
    o.delivered_at,
    o.cancelled_at,
    v.name as vendor_name,
    v.address as vendor_address,
    v.phone as vendor_phone,
    v.image_url as vendor_image_url,
    v.owner_id as vendor_owner_id,
    COALESCE(NULLIF(cp.full_name, ''), NULLIF(o.customer_name, ''), 'Guest User') as customer_name,
    COALESCE(NULLIF(cp.phone, ''), NULLIF(o.customer_phone, ''), 'No Phone') as customer_phone,
    cp.avatar_url as customer_avatar,
    dr.name as rider_name,
    dr.phone as rider_phone,
    dr.vehicle_number as rider_vehicle,
    dr.profile_image as rider_avatar,
    dr.rating as rider_rating,
    dr.total_orders as rider_total_orders,
    CASE 
        WHEN LOWER(o.status) = 'placed' THEN 'Order Placed'
        WHEN LOWER(o.status) = 'accepted' THEN 'Rider Assigned'
        WHEN LOWER(o.status) = 'preparing' THEN 'Chef is Cooking'
        WHEN LOWER(o.status) = 'ready' THEN 'Ready for Pickup'
        WHEN LOWER(o.status) = 'picked_up' THEN 'Food Picked Up'
        WHEN LOWER(o.status) = 'on_the_way' THEN 'Out for Delivery'
        WHEN LOWER(o.status) = 'delivered' THEN 'Delivered'
        ELSE UPPER(COALESCE(o.status, 'UNKNOWN'))
    END as status_display,
    CASE 
        WHEN UPPER(o.status) IN ('PLACED', 'ACCEPTED', 'RIDER_ASSIGNED') THEN 1
        WHEN UPPER(o.status) IN ('PREPARING', 'READY') THEN 2
        WHEN UPPER(o.status) = 'PICKED_UP' THEN 3
        WHEN UPPER(o.status) IN ('ON_THE_WAY', 'OUT_FOR_DELIVERY', 'TRANSIT') THEN 4
        WHEN UPPER(o.status) = 'DELIVERED' THEN 5
        ELSE 1
    END as current_step
FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id::text = v.id::text
LEFT JOIN public.customer_profiles cp ON o.customer_id::text = cp.id::text
LEFT JOIN public.delivery_riders dr ON o.rider_id::text = dr.id::text;

-- D. REPAIR TRIGGER FUNCTION
CREATE OR REPLACE FUNCTION handle_core_notifications_v4()
RETURNS TRIGGER AS $$
DECLARE
    v_customer_id text;
BEGIN
    v_customer_id := NEW.customer_id::text;

    IF (TG_OP = 'UPDATE') THEN
        IF (UPPER(COALESCE(NEW.status, '')) != UPPER(COALESCE(OLD.status, ''))) THEN
            CASE UPPER(NEW.status)
                WHEN 'ACCEPTED' THEN
                    INSERT INTO public.notifications (user_id, title, message, order_id, type, event_type, role)
                    VALUES (v_customer_id, 'Order Accepted 👨‍🍳', 'The restaurant has started preparing your order.', NEW.id::text, 'order', 'ORDER_ACCEPTED', 'CUSTOMER');
                WHEN 'PREPARING' THEN
                    INSERT INTO public.notifications (user_id, title, message, order_id, type, event_type, role)
                    VALUES (v_customer_id, 'Preparing Your Food', 'Your delicious meal is being prepared.', NEW.id::text, 'order', 'PREPARING', 'CUSTOMER');
                WHEN 'READY' THEN
                    INSERT INTO public.notifications (user_id, title, message, order_id, type, event_type, role)
                    VALUES (v_customer_id, 'Ready for Extraction', 'Rider is arriving to pick up your order.', NEW.id::text, 'order', 'READY', 'CUSTOMER');
                WHEN 'PICKED_UP', 'ON_THE_WAY', 'TRANSIT', 'OUT_FOR_DELIVERY' THEN
                    INSERT INTO public.notifications (user_id, title, message, order_id, type, event_type, role)
                    VALUES (v_customer_id, 'Out for Delivery 🚴', 'Your order is on the way!', NEW.id::text, 'order', 'IN_TRANSIT', 'CUSTOMER');
                WHEN 'DELIVERED' THEN
                    INSERT INTO public.notifications (user_id, title, message, order_id, type, event_type, role)
                    VALUES (v_customer_id, 'Delivered 🎉', 'Enjoy your meal! ⭐', NEW.id::text, 'order', 'DELIVERED', 'CUSTOMER');
                WHEN 'CANCELLED' THEN
                    INSERT INTO public.notifications (user_id, title, message, order_id, type, event_type, role)
                    VALUES (v_customer_id, 'Order Cancelled', 'Your order was cancelled. Refund initiated if applicable.', NEW.id::text, 'order', 'ORDER_CANCELLED', 'CUSTOMER');
                ELSE
            END CASE;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- E. ATTACH TRIGGER
DROP TRIGGER IF EXISTS tr_core_notifications_v4 ON public.orders;
CREATE TRIGGER tr_core_notifications_v4
AFTER UPDATE ON public.orders
FOR EACH ROW EXECUTE FUNCTION handle_core_notifications_v4();

-- F. REPAIR REALTIME BROADCAST
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        CREATE PUBLICATION supabase_realtime;
    END IF;

    IF (SELECT puballtables FROM pg_publication WHERE pubname = 'supabase_realtime') = false THEN
        IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'notifications') THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
        END IF;
    END IF;
END $$;

-- G. CLEAN UP
DROP TRIGGER IF EXISTS tr_ultimate_notifications ON public.orders;
DROP TRIGGER IF EXISTS tr_core_notifications_v3 ON public.orders;

COMMIT;

SELECT 'LOGISTICS RECOVERY v63 COMPLETE' as status;
