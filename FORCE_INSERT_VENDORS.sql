-- ==========================================
-- FORCE INSERT DUMMY VENDORS (LAST RESORT)
-- ==========================================

BEGIN;

-- 1. DELETE EXISTING VENDORS (To clear any corrupted data)
-- WARNING: This deletes all vendors. Only use if nothing else shows up.
DELETE FROM public.vendors;

-- 2. INSERT FRESH VALID VENDORS
-- Centered in Srivilliputhur (9.5127, 77.6337)
INSERT INTO public.vendors (
    name, 
    address, 
    latitude, 
    longitude, 
    status, 
    delivery_radius_km, 
    rating, 
    cuisine_type, 
    delivery_time, 
    is_pure_veg, 
    has_offers, 
    is_busy, 
    image_url, 
    banner_url
) VALUES 
(
    'Royal Curry House', 
    '123 Main Bazaar, Srivilliputhur', 
    9.5127, 
    77.6337, 
    'ONLINE', 
    9999.0, 
    4.8, 
    'South Indian, Chettinad', 
    '25-30 min', 
    FALSE, 
    TRUE, 
    FALSE,
    'https://images.unsplash.com/photo-1589302168068-964664d93dc0?w=800',
    'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=800'
),
(
    'Univ Curry Express', 
    '45 Temple Road, Srivilliputhur', 
    9.5150, 
    77.6350, 
    'ONLINE', 
    9999.0, 
    4.5, 
    'Biryani, North Indian', 
    '30-40 min', 
    FALSE, 
    FALSE, 
    FALSE,
    'https://images.unsplash.com/photo-1626074353765-517a681e40be?w=800',
    'https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=800'
),
(
    'Pure Veg Delight', 
    '88 Gandhi Road, Srivilliputhur', 
    9.5100, 
    77.6300, 
    'ONLINE', 
    9999.0, 
    4.2, 
    'Pure Veg, Tiffin', 
    '15-20 min', 
    TRUE, 
    TRUE, 
    FALSE,
    'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=800',
    'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=800'
),
(
    'Test Vendor (Pillaiyarnatham)', 
    'Pillaiyarnatham Main Road', 
    9.5000, 
    77.6337, 
    'ONLINE', 
    9999.0, 
    5.0, 
    'Testing', 
    '10-15 min', 
    FALSE, 
    FALSE, 
    FALSE,
    'https://images.unsplash.com/photo-1552566626-52f8b828add9?w=800',
    'https://images.unsplash.com/photo-1593560706856-b1a727e1b368?w=800'
);

COMMIT;
