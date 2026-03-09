-- 🏆 REALTIME TRACKING MASTER (V21.0)
-- Purpose: Fixes the "Searching for Rider" state and ensures Customer Address/Coordinates are 100% Realtime.

BEGIN;

-- 1. 🔓 UNLOCK TRACKING
DROP VIEW IF EXISTS public.order_details_v3 CASCADE;

-- 2. 🛠️ ALIGN LIVE LOCATION (Fixed UUID vs TEXT)
-- The app couldn't join Rider GPS because the types were mixed.
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

-- 3. 🛡️ PERFORMANCE INDEXES
CREATE INDEX IF NOT EXISTS idx_tracking_order ON public.delivery_live_location(order_id);

-- 4. 🔄 THE POWER VIEW (v3 - Tracking Optimized)
-- This view now pulls EVERY detail needed for the Tracking Map in one shot.
CREATE OR REPLACE VIEW public.order_details_v3 AS
SELECT 
    o.*,
    o.address as delivery_address, -- Alias for app compatibility
    o.delivery_lat as destination_lat,
    o.delivery_lng as destination_lng,
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
            LEFT JOIN public.delivery_live_location ll ON dr.id = ll.rider_id
            WHERE dr.id = o.rider_id
        ) r
    ) as rider_details
FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id = v.id
LEFT JOIN public.customer_profiles cp ON o.customer_id = cp.id;

GRANT SELECT ON public.order_details_v3 TO anon, authenticated, service_role;

-- 5. ⚡ ENSURE REALTIME BROADCAST
-- We force the entire system into "Full Identity" so no data is lost during transit.
ALTER TABLE public.orders REPLICA IDENTITY FULL;
ALTER TABLE public.vendors REPLICA IDENTITY FULL;
ALTER TABLE public.delivery_riders REPLICA IDENTITY FULL;
ALTER TABLE public.delivery_live_location REPLICA IDENTITY FULL;

-- Refresh Publication
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

-- 6. 🚀 GPS UPDATE HELPER (RPC)
-- This is what the Rider App calls to update the map in realtime.
CREATE OR REPLACE FUNCTION public.update_rider_location_v21(
    p_order_id UUID,
    p_rider_id UUID,
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION,
    p_heading DOUBLE PRECISION DEFAULT 0
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO public.delivery_live_location (rider_id, order_id, latitude, longitude, heading, updated_at)
    VALUES (p_rider_id, p_order_id, p_lat, p_lng, p_heading, now())
    ON CONFLICT (rider_id) DO UPDATE SET
        order_id = EXCLUDED.order_id,
        latitude = EXCLUDED.latitude,
        longitude = EXCLUDED.longitude,
        heading = EXCLUDED.heading,
        updated_at = now();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;

SELECT 'REALTIME TRACKING V21.0 READY - RIDER JOIN FIXED' as mission_status;
