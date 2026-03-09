-- 📡 NEURAL IDENTITY HARMONY (V11.9.4)
-- Purpose: Force a single, stable identity for the Demo Vendor

BEGIN;

-- 1. CLEANUP (Remove any duplicates that might confuse the lookup)
DELETE FROM public.vendors WHERE name = 'Royal Curry House';
DELETE FROM public.vendors WHERE owner_id = '00000000-0000-0000-0000-000000000001';

-- 2. INSERT STABLE DEMO VENDOR
-- We use a FIXED UUID for the vendor itself so order links remain stable
INSERT INTO public.vendors (
    id,
    name, 
    address, 
    latitude, 
    longitude, 
    status, 
    delivery_radius_km, 
    rating, 
    cuisine_type, 
    is_pure_veg, 
    image_url, 
    banner_url,
    owner_id
) VALUES 
(
    '11111111-1111-1111-1111-111111111111'::uuid,
    'Royal Curry House', 
    '123 Main Bazaar, Srivilliputhur', 
    9.5127, 
    77.6337, 
    'ONLINE', 
    999.0, 
    4.8, 
    'South Indian, Chettinad', 
    FALSE,
    'https://images.unsplash.com/photo-1589302168068-964664d93dc0?w=800',
    'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=800',
    '00000000-0000-0000-0000-000000000001'::uuid
);

-- 3. UPDATE ANY FLOATING ORDERS
-- If there are orders for "Royal Curry House" by name but wrong ID, link them.
UPDATE public.orders o
SET vendor_id = '11111111-1111-1111-1111-111111111111'::uuid
FROM public.vendors v
WHERE o.vendor_id = v.id AND v.name = 'Royal Curry House';

-- 4. ENSURE REALTIME IS ACTIVE
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

COMMIT;
