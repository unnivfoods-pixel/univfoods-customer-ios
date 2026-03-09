-- ==========================================
-- FORCE CLEANUP AND RESET (CORRECTED ORDER)
-- ==========================================

BEGIN;

-- 1. DELETE DEPENDENT TABLES FIRST (To avoid Foreign Key Constraints)
-- We must delete children before parents.
DELETE FROM public.products; 
DELETE FROM public.orders; 
-- Add any other tables that might reference vendors here if needed in future
-- DELETE FROM public.delivery_riders WHERE ... (if they are linked to vendors)

-- 2. NOW SAFELY DELETE VENDORS
DELETE FROM public.vendors;


-- 3. INSERT VENDORS WITH *EXACT* COORDINATES
-- Srivilliputhur Center: 9.5127, 77.6337
-- 15km Radius covers: Pillaiyarnatham, Watrap (maybe), Krishnankoil, Rajapalayam (North)

INSERT INTO public.vendors (
    name, address, latitude, longitude, 
    status, delivery_radius_km, 
    rating, cuisine_type, delivery_time, 
    is_pure_veg, image_url, banner_url, has_offers
) VALUES 
-- 1. Royal Curry House (Center of Srivi)
(
    'Royal Curry House', 
    '123 Gandhi Road, Srivilliputhur', 
    9.5127, 77.6337, 
    'ONLINE', 
    15.0, 
    4.8, 'South Indian, Chettinad', '25-30 min', 
    FALSE,
    'https://images.unsplash.com/photo-1589302168068-964664d93dc0?w=800',
    'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=800',
    TRUE
),
-- 2. Univ Curry Express (Near Temple - 1km away)
(
    'Univ Curry Express', 
    'North Mada St, Srivilliputhur', 
    9.5150, 77.6350, 
    'ONLINE', 
    15.0, 
    4.5, 'Biryani, Fast Food', '30-40 min', 
    FALSE,
    'https://images.unsplash.com/photo-1626074353765-517a681e40be?w=800',
    'https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=800',
    FALSE
),
-- 3. Pillaiyarnatham Special (Directly in Pillaiyarnatham - 5km away approx)
(
    'Pillaiyarnatham Tiffin Center', 
    'Main Bazaar, Pillaiyarnatham', 
    9.5400, 77.6600, -- Approximate Pillaiyarnatham coords
    'ONLINE', 
    15.0, 
    4.3, 'Tiffin, Pure Veg', '15-20 min', 
    TRUE,
    'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=800',
    'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=800',
    TRUE
),
-- 4. Krishnankoil (10km away - Should be visible)
(
    'Kalasalingam Food Court', 
    'Krishnankoil Main Road', 
    9.5800, 77.6800, 
    'ONLINE', 
    15.0, 
    4.0, 'Multi-Cuisine, Snacks', '40-50 min', 
    FALSE,
    'https://images.unsplash.com/photo-1552566626-52f8b828add9?w=800',
    'https://images.unsplash.com/photo-1593560706856-b1a727e1b368?w=800',
    FALSE
);

-- 4. INSERT SAMPLE PRODUCTS (so menus aren't empty)
-- We use subqueries to get the new IDs dynamically
INSERT INTO public.products (vendor_id, name, description, price, is_veg, image_url, category)
SELECT id, 'Chicken Biryani', 'Authentic Ambur style', 180, FALSE, 'https://images.unsplash.com/photo-1633945274405-b6c8069047b0?w=800', 'Biryani'
FROM public.vendors WHERE name = 'Univ Curry Express';

INSERT INTO public.products (vendor_id, name, description, price, is_veg, image_url, category)
SELECT id, 'Masala Dosa', 'Crispy with sambar', 60, TRUE, 'https://images.unsplash.com/photo-1589301760576-47f40569bbe9?w=800', 'Tiffin'
FROM public.vendors WHERE name = 'Royal Curry House';

INSERT INTO public.products (vendor_id, name, description, price, is_veg, image_url, category)
SELECT id, 'Idli Set', 'Soft idlis with chutney', 40, TRUE, 'https://images.unsplash.com/photo-1589301760576-47f40569bbe9?w=800', 'Tiffin'
FROM public.vendors WHERE name = 'Pillaiyarnatham Tiffin Center';


-- 5. RESTORE STRICT 15KM LOGIC IN RPC
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
            -- Haversine formula for distance
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
        COALESCE(v.has_offers, FALSE),
        COALESCE(v.is_busy, FALSE)
    FROM public.vendors v
    WHERE 
        -- 1. Status Check (Must be ONLINE)
        v.status = 'ONLINE'
        
        -- 2. Coordinate Check
        AND v.latitude IS NOT NULL 
        AND v.longitude IS NOT NULL
        
        -- 3. STRICT 15KM DISTANCE CHECK (Realtime Logic)
        AND (
            6371 * acos(
                LEAST(1.0, GREATEST(-1.0, 
                    cos(radians(customer_lat)) * cos(radians(v.latitude)) *
                    cos(radians(v.longitude) - radians(customer_lng)) +
                    sin(radians(customer_lat)) * sin(radians(v.latitude))
                ))
            )
        ) <= 15.0 -- HARD LIMIT 15KM
        
    ORDER BY distance_km ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
