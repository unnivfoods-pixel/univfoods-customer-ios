-- 📍 LOCATION SYSTEM OVERHAUL
-- 1. Update Vendors Table
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vendors' AND column_name = 'status') THEN
        ALTER TABLE public.vendors ADD COLUMN "status" TEXT DEFAULT 'ONLINE';
    END IF;

     IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vendors' AND column_name = 'delivery_radius_km') THEN
        -- Link radius_km to delivery_radius_km if it doesn't exist, or just use delivery_radius_km
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vendors' AND column_name = 'radius_km') THEN
             ALTER TABLE public.vendors RENAME COLUMN "radius_km" TO "delivery_radius_km";
        ELSE
             ALTER TABLE public.vendors ADD COLUMN "delivery_radius_km" DOUBLE PRECISION DEFAULT 15.0;
        END IF;
    END IF;

    -- MIGRATION: Update existing vendors to 15km if they are less (User Request)
    UPDATE public.vendors SET delivery_radius_km = 15.0 WHERE delivery_radius_km < 15.0 OR delivery_radius_km IS NULL;
END $$;

-- 2. HA VERSINE FUNCTION for RPC
DROP FUNCTION IF EXISTS public.get_nearby_vendors_v2(double precision, double precision);

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
        v.id,
        v.name,
        v.address,
        v.latitude,
        v.longitude,
        v.delivery_radius_km,
        v.status,
        (
            6371 * acos(
                LEAST(1.0, GREATEST(-1.0, 
                    cos(radians(customer_lat)) * cos(radians(v.latitude)) *
                    cos(radians(v.longitude) - radians(customer_lng)) +
                    sin(radians(customer_lat)) * sin(radians(v.latitude))
                ))
            )
        ) AS distance_km,
        v.rating,
        v.cuisine_type,
        v.image_url,
        v.banner_url,
        v.delivery_time,
        v.is_pure_veg,
        v.has_offers,
        v.is_busy
    FROM public.vendors v
    WHERE 
        v.status = 'ONLINE'
        AND (v.latitude IS NOT NULL AND v.longitude IS NOT NULL)
        AND (
            6371 * acos(
                LEAST(1.0, GREATEST(-1.0, 
                    cos(radians(customer_lat)) * cos(radians(v.latitude)) *
                    cos(radians(v.longitude) - radians(customer_lng)) +
                    sin(radians(customer_lat)) * sin(radians(v.latitude))
                ))
            )
        ) <= v.delivery_radius_km
    ORDER BY distance_km ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. CHECKOUT VALIDATION RPC (Renamed to match Cart Screen)
CREATE OR REPLACE FUNCTION public.validate_order_radius(
    v_id UUID,
    c_lat DOUBLE PRECISION,
    c_lng DOUBLE PRECISION
)
RETURNS BOOLEAN AS $$
DECLARE
    v_vendor RECORD;
    v_distance DOUBLE PRECISION;
BEGIN
    SELECT * INTO v_vendor FROM public.vendors WHERE id = v_id;
    
    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;

    IF v_vendor.status != 'ONLINE' THEN
        RETURN FALSE;
    END IF;

    -- Calculate distance
    v_distance := (
        6371 * acos(
            LEAST(1.0, GREATEST(-1.0, 
                cos(radians(c_lat)) * cos(radians(v_vendor.latitude)) *
                cos(radians(v_vendor.longitude) - radians(c_lng)) +
                sin(radians(c_lat)) * sin(radians(v_vendor.latitude))
            ))
        )
    );

    IF v_distance <= v_vendor.delivery_radius_km THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. TOGGLE VENDOR STATUS RPC
CREATE OR REPLACE FUNCTION public.admin_toggle_vendor(
    v_id UUID,
    is_online BOOLEAN
)
RETURNS VOID AS $$
BEGIN
    UPDATE public.vendors
    SET status = CASE WHEN is_online THEN 'ONLINE' ELSE 'OFFLINE' END
    WHERE id = v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
