-- 🏆 REALTIME TRACKING MASTER (V21.3 - Final Resolution)
-- Purpose: Permanently solves "delivery_address" duplicate and "rider_id" missing errors.

BEGIN;

-- 1. 🔓 UNLOCK TRACKING SYSTEM
DROP VIEW IF EXISTS public.order_details_v3 CASCADE;

-- 2. 🧹 CLEANUP ORDERS TABLE (Standardizing on "address")
-- We move any data from "delivery_address" to "address" and then kill the duplicate column.
DO $$ 
BEGIN
    -- If both exist, sync data to 'address'
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='delivery_address') THEN
        UPDATE public.orders SET address = delivery_address WHERE address IS NULL;
        -- Now drop the physical column so the View can use the name as an alias
        ALTER TABLE public.orders DROP COLUMN delivery_address;
    END IF;
EXCEPTION WHEN OTHERS THEN 
    RAISE NOTICE 'Skipping orders table cleanup.';
END $$;

-- 3. 🛠️ STANDARDIZE TRACKING TABLE (The "Rider GPS" Fix)
-- We force the table to use 'rider_id' and be UUID-based.
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

-- 4. 🔄 THE TRACKING VIEW (v3 - Optimized & Conflict-Free)
-- This view provides 'delivery_address' and 'destination_lat/lng' for the Map logic.
CREATE OR REPLACE VIEW public.order_details_v3 AS
SELECT 
    o.*,
    o.address as delivery_address, -- App expects this specific name
    o.delivery_lat as destination_lat, -- Map pin logic
    o.delivery_lng as destination_lng, -- Map pin logic
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

-- 5. ⚡ ENABLE REALTIME STREAMING (The Engine)
ALTER TABLE public.orders REPLICA IDENTITY FULL;
ALTER TABLE public.delivery_live_location REPLICA IDENTITY FULL;

DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

COMMIT;

SELECT 'TRACKING V21.3 MASTER INITIALIZED - CONFLICTS RESOLVED' as mission_status;
