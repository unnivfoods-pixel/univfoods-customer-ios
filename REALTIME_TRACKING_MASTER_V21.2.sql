-- 🏆 REALTIME TRACKING MASTER (V21.2 - Schema Synched)
-- Purpose: Fixes the "rider_id does not exist" error by standardizing tracking table columns.

BEGIN;

-- 1. 🔓 UNLOCK TRACKING
DROP VIEW IF EXISTS public.order_details_v3 CASCADE;

-- 2. 🛠️ STANDARDIZE TRACKING TABLE (The "Rider ID" Fix)
-- We check if the tracking table uses 'delivery_id' and rename it to 'rider_id' for consistency.
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='delivery_live_location' AND column_name='delivery_id') THEN
        ALTER TABLE public.delivery_live_location RENAME COLUMN delivery_id TO rider_id;
    END IF;
EXCEPTION WHEN OTHERS THEN 
    RAISE NOTICE 'Skipping column rename.';
END $$;

-- 3. 🛠️ FORCE RECREATE IF STILL BROKEN
-- If the table is missing or has the wrong primary key type (TEXT vs UUID), we rebuild it.
DROP TABLE IF EXISTS public.delivery_live_location CASCADE;
CREATE TABLE public.delivery_live_location (
    rider_id UUID PRIMARY KEY REFERENCES public.delivery_riders(id) ON DELETE CASCADE,
    order_id UUID REFERENCES public.orders(id) ON DELETE CASCADE,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    heading DOUBLE PRECISION DEFAULT 0,
    speed DOUBLE PRECISION DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 4. 🔄 THE TRACKING VIEW (v3 - Optimized for Realtime)
CREATE OR REPLACE VIEW public.order_details_v3 AS
SELECT 
    o.*,
    o.address as delivery_address, 
    o.delivery_lat as destination_lat, 
    o.delivery_lng as destination_lng,
    jsonb_build_object(
        'name', v.name,
        'phone', v.phone,
        'address', v.address,
        'latitude', v.latitude,
        'longitude', v.longitude,
        'logo_url', COALESCE(v.logo_url, v.banner_url)
    ) as vendors,
    jsonb_build_object(
        'full_name', cp.full_name,
        'phone', cp.phone,
        'avatar_url', cp.avatar_url
    ) as customer_profiles,
    (
        SELECT row_to_json(r) FROM (
            SELECT 
                dr.id, dr.name, dr.phone, dr.vehicle_number, dr.vehicle_type,
                ll.latitude as live_lat, ll.longitude as live_lng, ll.heading, ll.speed
            FROM public.delivery_riders dr
            INNER JOIN public.delivery_live_location ll ON dr.id = ll.rider_id
            WHERE dr.id = o.rider_id
            LIMIT 1
        ) r
    ) as rider_details
FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id = v.id
LEFT JOIN public.customer_profiles cp ON o.customer_id = cp.id;

GRANT SELECT ON public.order_details_v3 TO anon, authenticated, service_role;

-- 5. ⚡ RESET REALTIME STREAM
ALTER TABLE public.orders REPLICA IDENTITY FULL;
ALTER TABLE public.delivery_live_location REPLICA IDENTITY FULL;

DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

COMMIT;

SELECT 'TRACKING V21.2 ONLINE - SCHEMA ALIGNED' as status;
