-- 🔥 REALTIME RECOVERY & GEO FIX (V18.1 - Resilience Edition)
-- Purpose: Force-enable realtime for all critical tables and fix geospatial response mismatch.
-- This version is "Silent" - it won't crash if the Financial Ledger tables aren't created yet.

BEGIN;

-- 1. REPAIR REALTIME PUBLICATION (Safely)
-- If the publication exists, we'll rebuild it to include everything available.
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime;

-- 2. ADD TABLES TO PUBLICATION (Check existence for each to skip missing modules)
DO $$
DECLARE
    t_name TEXT;
    critical_tables TEXT[] := ARRAY[
        'vendors', 'products', 'categories', 'orders', 'order_items', 
        'delivery_riders', 'delivery_live_location', 'wallets', 
        'financial_ledger', 'disputes', 'chat_messages'
    ];
BEGIN
    FOREACH t_name IN ARRAY critical_tables LOOP
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = t_name) THEN
            EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t_name);
            EXECUTE format('ALTER TABLE public.%I REPLICA IDENTITY FULL', t_name);
        END IF;
    END LOOP;
END $$;

-- 3. BULLETPROOF GEOSPATIAL RPC (v16)
-- Resolves "structure of query does not match" & "uuid/text mismatch" errors.
DROP FUNCTION IF EXISTS public.get_nearby_vendors_v16(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION);

CREATE OR REPLACE FUNCTION public.get_nearby_vendors_v16(
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION,
    p_max_dist_km DOUBLE PRECISION DEFAULT 15.0
)
RETURNS TABLE (
    id UUID, 
    name TEXT,
    cuisine_type TEXT,
    rating DOUBLE PRECISION,
    banner_url TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    distance_km DOUBLE PRECISION,
    is_open BOOLEAN,
    status TEXT,
    is_pure_veg BOOLEAN,
    has_offers BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        v.id::UUID, 
        v.name::TEXT, 
        v.cuisine_type::TEXT, 
        COALESCE(v.rating, 5.0)::DOUBLE PRECISION, 
        COALESCE(v.banner_url, v.image_url)::TEXT, 
        v.latitude::DOUBLE PRECISION, 
        v.longitude::DOUBLE PRECISION,
        (
            6371 * acos(
                LEAST(1.0, GREATEST(-1.0, 
                    cos(radians(p_lat)) * cos(radians(v.latitude)) * 
                    cos(radians(v.longitude) - radians(p_lng)) + 
                    sin(radians(p_lat)) * sin(radians(v.latitude))
                ))
            )
        )::DOUBLE PRECISION AS distance_km,
        COALESCE(v.is_open, TRUE)::BOOLEAN,
        COALESCE(v.status, 'ONLINE')::TEXT,
        COALESCE(v.is_pure_veg, FALSE)::BOOLEAN,
        COALESCE(v.has_offers, FALSE)::BOOLEAN
    FROM public.vendors v
    WHERE 
      (v.is_active = TRUE OR v.is_approved = TRUE)
      AND v.latitude IS NOT NULL 
      AND v.longitude IS NOT NULL
      AND (
            6371 * acos(
                LEAST(1.0, GREATEST(-1.0, 
                    cos(radians(p_lat)) * cos(radians(v.latitude)) * 
                    cos(radians(v.longitude) - radians(p_lng)) + 
                    sin(radians(p_lat)) * sin(radians(v.latitude))
                ))
            )
        ) <= COALESCE(v.delivery_radius_km, p_max_dist_km)
    ORDER BY distance_km ASC;
END;
$$ LANGUAGE plpgsql STABLE;

-- 4. EXPLORE TAB FIX (v2)
DROP FUNCTION IF EXISTS public.get_nearby_vendors_v2(DOUBLE PRECISION, DOUBLE PRECISION);
CREATE OR REPLACE FUNCTION public.get_nearby_vendors_v2(
    customer_lat DOUBLE PRECISION,
    customer_lng DOUBLE PRECISION
)
RETURNS TABLE (
    id UUID,
    name TEXT,
    address TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    delivery_radius_km DOUBLE PRECISION,
    status TEXT,
    distance_km DOUBLE PRECISION,
    rating DOUBLE PRECISION,
    cuisine_type TEXT,
    image_url TEXT,
    banner_url TEXT,
    delivery_time TEXT,
    is_pure_veg BOOLEAN,
    has_offers BOOLEAN,
    is_busy BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        v.id::UUID,
        v.name::TEXT,
        v.address::TEXT,
        v.latitude::DOUBLE PRECISION,
        v.longitude::DOUBLE PRECISION,
        v.delivery_radius_km::DOUBLE PRECISION,
        v.status::TEXT,
        (
            6371 * acos(
                LEAST(1.0, GREATEST(-1.0, 
                    cos(radians(customer_lat)) * cos(radians(v.latitude)) *
                    cos(radians(v.longitude) - radians(customer_lng)) +
                    sin(radians(customer_lat)) * sin(radians(v.latitude))
                ))
            )
        )::DOUBLE PRECISION AS distance_km,
        v.rating::DOUBLE PRECISION,
        v.cuisine_type::TEXT,
        v.image_url::TEXT,
        v.banner_url::TEXT,
        v.delivery_time::TEXT,
        COALESCE(v.is_pure_veg, FALSE)::BOOLEAN,
        COALESCE(v.has_offers, FALSE)::BOOLEAN,
        COALESCE(v.is_busy, FALSE)::BOOLEAN
    FROM public.vendors v
    WHERE v.status IN ('ONLINE', 'active')
    ORDER BY distance_km ASC;
END;
$$ LANGUAGE plpgsql STABLE;

-- 5. Final Schema Alignment
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS category TEXT;
UPDATE public.vendors SET status = 'ONLINE' WHERE status = 'active';

COMMIT;
