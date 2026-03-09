-- ?? REALTIME CONNECTION FIX V1
-- MISSION: Make the Admin Toggle "Actionable" in the Customer App.
-- This script ensures that when you toggle a vendor OFFLINE, they don't just vanish,
-- but stay in the list and show as "CLOSED" in the customer app.

BEGIN;

-- 1. Update the Open Logic to be more permissive for the Search RPC
-- We want the RPC to return the vendor, so the app can show the "CLOSED" sticker.
CREATE OR REPLACE FUNCTION public.get_nearby_vendors_v21(p_params JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_lat DOUBLE PRECISION;
    v_lng DOUBLE PRECISION;
    v_max_radius DOUBLE PRECISION := 15.0;
BEGIN
    v_lat := (p_params->>'lat')::DOUBLE PRECISION;
    v_lng := (p_params->>'lng')::DOUBLE PRECISION;

    -- Handle alternative parameter naming (Direct lat/lng)
    IF v_lat IS NULL THEN v_lat := (p_params->>'p_lat')::DOUBLE PRECISION; END IF;
    IF v_lng IS NULL THEN v_lng := (p_params->>'p_lng')::DOUBLE PRECISION; END IF;

    IF v_lat IS NULL OR v_lng IS NULL OR (v_lat = 0 AND v_lng = 0) THEN
        RETURN '[]'::jsonb;
    END IF;

    RETURN (
        SELECT COALESCE(jsonb_agg(v_row), '[]'::jsonb)
        FROM (
            SELECT 
                v.*,
                public.calculate_distance_km(v_lat, v_lng, v.latitude, v.longitude) AS distance_km
            FROM public.vendors v
            WHERE 
                v.is_verified = TRUE
                AND v.is_active = TRUE
                -- ?? REMOVED the strict 'is_open' filter so "CLOSED" shops stay visible in list
                AND v.latitude IS NOT NULL 
                AND v.longitude IS NOT NULL
                AND public.calculate_distance_km(v_lat, v_lng, v.latitude, v.longitude) <= COALESCE(v.delivery_radius_km, v_max_radius)
            ORDER BY distance_km ASC
        ) v_row
    );
END;
$$;

-- 2. Ensure Real-time is sending Full Records for instant UI updates
ALTER TABLE public.vendors REPLICA IDENTITY FULL;

COMMIT;

SELECT 'REALTIME ACTION CONNECTED: Vendors will now show as CLOSED when toggled.' as status;
