
-- ULTIMATE PRODUCTION PIPELINE V55.2 (IMAGE URI & ERROR HANDLING FIX)
-- 🎯 MISSION: Fix "Invalid argument(s): No host specified in URI file:///" crash.

BEGIN;

-- 1. FIX VENDORS WITH BAD ARTIFACT URIs
UPDATE vendors 
SET 
  banner_url = 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=800',
  image_url = 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=800'
WHERE banner_url LIKE 'file://%' 
   OR image_url LIKE 'file://%';

-- 2. FIX PRODUCTS WITH BAD ARTIFACT URIs
UPDATE products 
SET 
  image_url = 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=800'
WHERE image_url LIKE 'file://%';

COMMIT;
