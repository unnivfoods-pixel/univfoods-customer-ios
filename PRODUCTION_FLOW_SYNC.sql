-- =============================================================================
-- FULL PRODUCTION FLOW DATABASE SYNC (V2 - CONSISTENT NAMING)
-- Targets: Orders, Payments, Statuses, and GPS
-- =============================================================================

-- 1. Ensure Orders Table has correct columns
DO $$
BEGIN
    -- Payment Method
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'payment_method') THEN
        ALTER TABLE "orders" ADD COLUMN "payment_method" text DEFAULT 'online'; -- 'online' or 'cod'
    END IF;

    -- Payment Status
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'payment_status') THEN
        ALTER TABLE "orders" ADD COLUMN "payment_status" text DEFAULT 'unpaid'; -- 'unpaid', 'paid', 'refunded'
    END IF;

    -- Cancellation Reason
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'cancellation_reason') THEN
        ALTER TABLE "orders" ADD COLUMN "cancellation_reason" text;
    END IF;
END $$;

-- 2. Data Migration: Convert existing statuses to lowercase equivalents
UPDATE public.orders 
SET status = LOWER(TRIM(status));

-- Map old human-readable statuses to new machine-readable equivalents if they differ
UPDATE public.orders SET status = 'on_the_way' WHERE status = 'out for delivery';
UPDATE public.orders SET status = 'picked_up' WHERE status = 'picked up';
UPDATE public.orders SET status = 'placed' WHERE status = 'pending';

-- 3. Update Status Constraint to match Requirements Page exactly
ALTER TABLE "orders" DROP CONSTRAINT IF EXISTS "orders_status_check";
ALTER TABLE "orders" ADD CONSTRAINT "orders_status_check" 
CHECK (status IN (
    'placed', 
    'accepted', 
    'preparing', 
    'ready', 
    'picked_up', 
    'on_the_way', 
    'delivered', 
    'cancelled',
    'refused' 
));

-- 4. Ensure Delivery Riders Table has correct GPS columns (latitude/longitude)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'delivery_riders' AND column_name = 'latitude') THEN
        ALTER TABLE "delivery_riders" ADD COLUMN "latitude" double precision;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'delivery_riders' AND column_name = 'longitude') THEN
        ALTER TABLE "delivery_riders" ADD COLUMN "longitude" double precision;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'delivery_riders' AND column_name = 'heading') THEN
        ALTER TABLE "delivery_riders" ADD COLUMN "heading" double precision DEFAULT 0.0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'delivery_riders' AND column_name = 'last_updated') THEN
        ALTER TABLE "delivery_riders" ADD COLUMN "last_updated" timestamp with time zone DEFAULT now();
    END IF;
END $$;

-- 4. Create App Settings for the 15km Delivery Radius
INSERT INTO public.app_settings (key, value)
VALUES ('delivery_config', '{"max_radius_km": 15, "min_order_value": 0}'::jsonb)
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

-- 5. Helper Function to determine if refund is allowed
CREATE OR REPLACE FUNCTION public.can_refund_order(order_row public.orders)
RETURNS boolean AS $$
BEGIN
    RETURN (order_row.status = 'placed' OR order_row.status = 'accepted') 
           AND order_row.payment_method = 'online' 
           AND order_row.payment_status = 'paid';
END;
$$ LANGUAGE plpgsql;

-- 6. Grant Permissions
GRANT ALL ON TABLE "orders" TO anon, authenticated, service_role;
GRANT ALL ON TABLE "delivery_riders" TO anon, authenticated, service_role;
GRANT ALL ON TABLE "app_settings" TO anon, authenticated, service_role;

-- 7. Ensure real-time is enabled (Safe check)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'orders') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'delivery_riders') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.delivery_riders;
    END IF;
END $$;

-- 8. Seed Legal Documents (Policies)
-- Ensure title is unique for ON CONFLICT to work
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'legal_documents_title_key') THEN
        ALTER TABLE public.legal_documents ADD CONSTRAINT legal_documents_title_key UNIQUE (title);
    END IF;
END $$;

INSERT INTO public.legal_documents (title, content, category, status, target_audience, version)
VALUES 
('Cancellation Policy', 
 'Full refund is applicable for orders in Placed status. Once the vendor marks the order as Preparing, no refund is possible. Online payments will be refunded to the original source within 5–7 business days.', 
 'General', 'published', 'ALL', '1.0'),
('Refund Policy', 
 'Refunds are only applicable for online payments. Cash on Delivery (COD) orders are naturally exempt from refunds. If a vendor rejects the order, the full amount is automatically refunded.', 
 'General', 'published', 'CUSTOMER', '1.0')
ON CONFLICT (title) DO UPDATE SET content = EXCLUDED.content;
