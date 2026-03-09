-- UNIVERSAL REALTIME FIX V3
-- This script does 4 things:
-- 1. Cleans up all data (Vendors, Products, Orders) to remove bad states.
-- 2. Inserts 4 precise vendors in Srivilliputhur/Pillaiyarnatham.
-- 3. Resets the RPC function to enforce 15km radius (Realtime check).
-- 4. Ensures Realtime is enabled for Admin/Vendor connection.

-- 1. CLEANUP (Use TRUNCATE to avoid FK issues)
TRUNCATE TABLE public.vendors CASCADE;
-- (Products and Orders are deleted automatically due to CASCADE)

-- 2. ENABLE REALTIME & DISABLE VISIBILITY RESTRICTIONS
-- We want everyone to see these vendors for now.
ALTER TABLE public.vendors DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.products DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders DISABLE ROW LEVEL SECURITY;

-- Ensure tables are in the realtime publication
ALTER PUBLICATION supabase_realtime ADD TABLE vendors;
ALTER PUBLICATION supabase_realtime ADD TABLE products;
ALTER PUBLICATION supabase_realtime ADD TABLE orders;

-- Ensure Replica Identity (Crucial for Update/Delete events)
ALTER TABLE public.vendors REPLICA IDENTITY FULL;
ALTER TABLE public.products REPLICA IDENTITY FULL;
ALTER TABLE public.orders REPLICA IDENTITY FULL;

-- 3. INSERT VENDORS (Srivilliputhur & Pillaiyarnatham)
INSERT INTO public.vendors (
    name, 
    address, 
    latitude, 
    longitude, 
    delivery_radius_km, 
    status, 
    rating, 
    cuisine_type, 
    image_url, 
    banner_url, 
    delivery_time, 
    is_pure_veg, 
    has_offers, 
    is_busy, 
    open_time, 
    close_time
) VALUES 
-- 1. Pillaiyarnatham Tiffin Center (IN INVALID PILLAIYARNATHAM)
(
    'Pillaiyarnatham Tiffin Center',
    'Main Road, Pillaiyarnatham, Srivilliputhur',
    9.5298, 
    77.6209, 
    15.0,
    'ONLINE',
    4.8,
    'South Indian',
    'https://images.unsplash.com/photo-1589302168068-964664d93dc0?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1505253758473-96b701d22410?auto=format&fit=crop&w=1200&q=80',
    '10-20 min',
    TRUE,
    TRUE,
    FALSE,
    '07:00',
    '23:00'
),
-- 2. Royal Curry House (Center Srivi)
(
    'Royal Curry House',
    'Near Andal Temple, Srivilliputhur',
    9.5127, 
    77.6337, 
    15.0,
    'ONLINE',
    4.5,
    'Chettinad Special',
    'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=1200&q=80',
    '25-35 min',
    FALSE,
    TRUE,
    FALSE,
    '10:00',
    '22:00'
),
-- 3. Univ Curry Express (Srivi North)
(
    'Univ Curry Express',
    'North Car Street, Srivilliputhur',
    9.5180,
    77.6300,
    15.0,
    'ONLINE',
    4.2,
    'North Indian',
    'https://images.unsplash.com/photo-1585937421612-70a008356f36?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1552566626-52f8b828add9?auto=format&fit=crop&w=1200&q=80',
    '30-45 min',
    FALSE,
    FALSE,
    FALSE,
    '11:00',
    '23:00'
),
-- 4. Kalasalingam Court (Krishnankoil - Far away but barely 10km)
(
    'Kalasalingam Food Court',
    'Krishnankoil, Srivilliputhur Main Rd',
    9.5872,
    77.6695,
    15.0,
    'ONLINE',
    4.0,
    'Multi Cuisine',
    'https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=1200&q=80',
    '45-60 min',
    FALSE,
    TRUE,
    FALSE,
    '08:00',
    '21:00'
);

-- 4. INSERT PRODUCTS (Sample Data)
INSERT INTO public.products (
    vendor_id,
    name,
    description,
    price,
    is_veg,
    image_url,
    category
)
SELECT id, 'Chicken Biryani', 'Classic Hyderabadi Style', 220.00, FALSE, 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8', 'Main Course'
FROM public.vendors WHERE name = 'Royal Curry House';

INSERT INTO public.products (
    vendor_id,
    name,
    description,
    price,
    is_veg,
    image_url,
    category
)
SELECT id, 'Masala Dosa', 'Crispy Dosa with Potato Masala', 80.00, TRUE, 'https://images.unsplash.com/photo-1589301760014-d929f3979dbc', 'Breakfast'
FROM public.vendors WHERE name = 'Pillaiyarnatham Tiffin Center';

INSERT INTO public.products (
    vendor_id,
    name,
    description,
    price,
    is_veg,
    image_url,
    category
)
SELECT id, 'Paneer Butter Masala', 'Rich creamy gravy', 180.00, TRUE, 'https://images.unsplash.com/photo-1631452180519-c014fe946bc7', 'Curries'
FROM public.vendors WHERE name = 'Univ Curry Express';

-- 5. UPDATE RPC FOR 15KM REALTIME (Strict & Secure)
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
        v.status = 'ONLINE' -- Only Realtime Online Vendors
        AND (v.latitude IS NOT NULL AND v.longitude IS NOT NULL)
        AND (
            6371 * acos(
                LEAST(1.0, GREATEST(-1.0, 
                    cos(radians(customer_lat)) * cos(radians(v.latitude)) *
                    cos(radians(v.longitude) - radians(customer_lng)) +
                    sin(radians(customer_lat)) * sin(radians(v.latitude))
                ))
            )
        ) <= 15.0 -- STRICT 15KM LIMIT
    ORDER BY distance_km ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions to make sure everyone can call it
GRANT EXECUTE ON FUNCTION public.get_nearby_vendors_v2 TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.vendors TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.products TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.orders TO anon, authenticated, service_role;

-- Verification
SELECT name, status, latitude, longitude FROM public.vendors;
