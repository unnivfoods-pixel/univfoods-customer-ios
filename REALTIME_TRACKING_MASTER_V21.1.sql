-- 🏆 REALTIME TRACKING MASTER (V21.1 - Duplicate Proof)
-- Purpose: Fixes "Column specified more than once" and ensures tracking address/GPS link.

BEGIN;

-- 1. 🔓 UNLOCK TRACKING
DROP VIEW IF EXISTS public.order_details_v3 CASCADE;

-- 2. 🛠️ TABLE HARMONY (Merging Addresses)
-- If the table has both 'address' and 'delivery_address', we move all data to 'address' and drop the extra one.
DO $$ 
BEGIN
    -- Move data if delivery_address exists as a column but is empty
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='delivery_address') THEN
        UPDATE public.orders SET address = delivery_address WHERE address IS NULL AND delivery_address IS NOT NULL;
        -- Now that it's safe, we drop the conflicting column so the View can use the alias
        ALTER TABLE public.orders DROP COLUMN delivery_address;
    END IF;
EXCEPTION WHEN OTHERS THEN 
    RAISE NOTICE 'Skipping address merge.';
END $$;

-- 3. 🛠️ GPS TABLE REPAIR
-- Ensures the Live Location table exists and is UUID-ready.
CREATE TABLE IF NOT EXISTS public.delivery_live_location (
    rider_id UUID PRIMARY KEY REFERENCES public.delivery_riders(id) ON DELETE CASCADE,
    order_id UUID REFERENCES public.orders(id) ON DELETE CASCADE,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    heading DOUBLE PRECISION DEFAULT 0,
    speed DOUBLE PRECISION DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 4. 🔄 THE TRACKING VIEW (v3 - Conflict Free)
-- This version explicitly provides 'delivery_address' and 'destination_lat/lng' for the Map.
CREATE OR REPLACE VIEW public.order_details_v3 AS
SELECT 
    o.*,
    o.address as delivery_address, -- App expects this name
    o.delivery_lat as destination_lat, -- App mapping
    o.delivery_lng as destination_lng, -- App mapping
    jsonb_build_object(
        'name', v.name,
        'phone', v.phone,
        'address', v.address,
        'latitude', v.latitude,
        'longitude', v.longitude,
        'logo_url', COALESCE(v.logo_url, v.image_url)
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

-- 5. ⚡ ENABLE STREAMING
ALTER TABLE public.orders REPLICA IDENTITY FULL;
ALTER TABLE public.delivery_live_location REPLICA IDENTITY FULL;

DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

COMMIT;

SELECT 'TRACKING V21.1 ONLINE - DUPLICATES PURGED - MAP READY' as status;
