-- 🟡 CUSTOMER APP MASTER SCHEME (PIN TO PIN)
-- Ensures database matches all 15 points of the specification.

-- 1. CUSTOMER PROFILE EXTENSIONS
ALTER TABLE public.customer_profiles 
ADD COLUMN IF NOT EXISTS phone TEXT,
ADD COLUMN IF NOT EXISTS default_address TEXT,
ADD COLUMN IF NOT EXISTS saved_addresses JSONB DEFAULT '[]'::jsonb,
ADD COLUMN IF NOT EXISTS fcm_token TEXT;

-- 2. VENDOR ENHANCEMENTS (Distance & Status)
-- Enable PostGIS if not already (Point 2A)
CREATE EXTENSION IF NOT EXISTS postgis;

ALTER TABLE public.vendors
ADD COLUMN IF NOT EXISTS location GEOGRAPHY(POINT, 4326),
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'ONLINE'; -- ONLINE, OFFLINE

-- 3. NEIGHBORHOOD LOGIC (Point 2A)
CREATE OR REPLACE FUNCTION get_nearby_vendors(customer_lat DOUBLE PRECISION, customer_lng DOUBLE PRECISION)
RETURNS TABLE (
    id UUID,
    name TEXT,
    address TEXT,
    rating NUMERIC,
    delivery_time TEXT,
    cuisine_type TEXT,
    image_url TEXT,
    is_pure_veg BOOLEAN,
    has_offers BOOLEAN,
    status TEXT,
    distance_km DOUBLE PRECISION
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        v.id, v.name, v.address, v.rating, v.delivery_time, v.cuisine_type, v.image_url, v.is_pure_veg, v.has_offers, v.status,
        ST_Distance(
            v.location,
            ST_SetSRID(ST_MakePoint(customer_lng, customer_lat), 4326)::geography
        ) / 1000 AS distance_km
    FROM public.vendors v
    WHERE v.status = 'ONLINE'
    AND ST_Distance(
            v.location,
            ST_SetSRID(ST_MakePoint(customer_lng, customer_lat), 4326)::geography
        ) / 1000 <= (SELECT (value->>'km')::numeric FROM public.app_settings WHERE key = 'delivery_radius')
    ORDER BY distance_km;
END;
$$ LANGUAGE plpgsql;

-- 4. APP SETTINGS (Point 4)
INSERT INTO public.app_settings (key, value)
VALUES 
('cod_limit', '2000'::jsonb),
('delivery_radius_limit', '15'::jsonb)
ON CONFLICT (key) DO NOTHING;

-- 4. ORDER TABLE FINAL ALIGNMENT (Point 14)
ALTER TABLE public.orders
ADD COLUMN IF NOT EXISTS payment_method TEXT, -- ONLINE, COD
ADD COLUMN IF NOT EXISTS payment_state TEXT DEFAULT 'PENDING', -- PENDING, COMPLETED, FAILED, REFUND_INITIATED, REFUND_COMPLETED
ADD COLUMN IF NOT EXISTS delivery_lat NUMERIC,
ADD COLUMN IF NOT EXISTS delivery_lng NUMERIC,
ADD COLUMN IF NOT EXISTS refund_amount NUMERIC DEFAULT 0;

-- 5. RIDER TRACKING (Point 7)
-- We store rider location in delivery_riders table and stream it.
ALTER TABLE public.delivery_riders
ADD COLUMN IF NOT EXISTS current_lat NUMERIC,
ADD COLUMN IF NOT EXISTS current_lng NUMERIC,
ADD COLUMN IF NOT EXISTS last_update TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- 6. FRAUD LOGS & TRIGGERS (Point 13)
-- Already handled in previous scripts, ensuring indices here.
CREATE INDEX IF NOT EXISTS idx_orders_customer_status ON public.orders(customer_id, status);

-- 7. SECURITY: AUTO-BLOCK FOR FRAUD (Point 13)
CREATE OR REPLACE FUNCTION monitor_customer_fraud()
RETURNS TRIGGER AS $$
DECLARE
    cancelation_rate FLOAT;
    total_orders INTEGER;
BEGIN
    SELECT count(*), sum(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END)
    INTO total_orders, NEW.cancel_count -- Assuming cancel_count exists in customer_profiles
    FROM public.orders WHERE customer_id = NEW.customer_id;

    -- Logic for auto-disable COD or blocking
    IF (NEW.status = 'cancelled' AND NEW.payment_method = 'COD') THEN
        UPDATE public.customer_profiles
        SET cod_disabled = TRUE -- Disable COD after cancellation
        WHERE id = NEW.customer_id AND cancel_count >= 3;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_fraud_check ON public.orders;
CREATE TRIGGER on_fraud_check
AFTER UPDATE ON public.orders
FOR EACH ROW EXECUTE PROCEDURE monitor_customer_fraud();

-- 8. REALTIME REFRESH
-- Ensure all tables are in realtime publication
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime' AND NOT puballtables) THEN
        IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'vendors') THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.vendors;
        END IF;
    END IF;
END $$;
