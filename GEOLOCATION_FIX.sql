-- 🌍 GEOLOCATION REPAIR & REALTIME VENDOR SYNC
-- Fixes ST_Distance logic and ensures radius settings are correct.

-- 1. FIX APP SETTINGS (Point 4 Alignment)
INSERT INTO public.app_settings (key, value)
VALUES 
('delivery_radius', '{"km": 25}'::jsonb),
('cod_limit', '5000'::jsonb)
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

-- 2. REPAIR get_nearby_vendors FUNCTION
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
DECLARE
    v_radius NUMERIC;
BEGIN
    -- Get radius from settings or default to 25km
    SELECT (value->>'km')::numeric INTO v_radius FROM public.app_settings WHERE key = 'delivery_radius';
    IF v_radius IS NULL THEN v_radius := 25; END IF;

    RETURN QUERY
    SELECT 
        v.id, v.name, v.address, v.rating, v.delivery_time, v.cuisine_type, v.image_url, v.is_pure_veg, v.has_offers, v.status,
        ST_Distance(
            v.location,
            ST_SetSRID(ST_MakePoint(customer_lng, customer_lat), 4326)::geography
        ) / 1000 AS distance_km
    FROM public.vendors v
    WHERE (v.status = 'ONLINE' OR v.status = 'Active')
    AND (
        ST_Distance(
            v.location,
            ST_SetSRID(ST_MakePoint(customer_lng, customer_lat), 4326)::geography
        ) / 1000 <= v_radius
        OR v.location IS NULL -- Show vendors with no location as fallback for now
    )
    ORDER BY (v.location IS NULL), distance_km;
END;
$$ LANGUAGE plpgsql;

-- 3. SEED REALISTIC VENDORS (Srivilliputhur Nodes)
-- Coords for Srivilliputhur approx: 9.5092, 77.6322
INSERT INTO public.vendors (id, name, address, cuisine_type, status, rating, delivery_time, is_pure_veg, has_offers, location)
VALUES
('b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a12', 'Srivilliputhur Palkova Center', 'Main Bazaar, Srivilliputhur', 'Sweets', 'ONLINE', 4.9, '15-20 mins', true, true, ST_SetSRID(ST_MakePoint(77.6322, 9.5092), 4326)::geography),
('c1eebc99-9c0b-4ef8-bb6d-6bb9bd380a13', 'Amma Mess', 'Railway Station Road', 'South Indian', 'ONLINE', 4.5, '20-25 mins', false, false, ST_SetSRID(ST_MakePoint(77.6350, 9.5110), 4326)::geography),
('d1eebc99-9c0b-4ef8-bb6d-6bb9bd380a14', 'The Curry Point', 'Madurai Road', 'Curry Specialties', 'ONLINE', 4.7, '25-30 mins', false, true, ST_SetSRID(ST_MakePoint(77.6300, 9.5050), 4326)::geography)
ON CONFLICT (id) DO UPDATE SET 
    location = EXCLUDED.location,
    status = EXCLUDED.status;

-- 4. ENABLE REALTIME FOR VENDORS
ALTER TABLE public.vendors REPLICA IDENTITY FULL;
-- Handled in publications already but good to ensure
