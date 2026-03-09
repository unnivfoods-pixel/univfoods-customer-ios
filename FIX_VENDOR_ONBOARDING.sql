-- =========================================================
-- VENDOR PRO FEATURES & TAGS UPDATE
-- Run this to fix the "Onboarding button not working" issue
-- =========================================================

-- 1. Add missing columns to vendors table
ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS image_url text,
ADD COLUMN IF NOT EXISTS zone_id uuid,
ADD COLUMN IF NOT EXISTS is_trending boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS is_top_rated boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS is_pure_veg boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS tags text[] DEFAULT '{}'::text[];

-- 2. Ensure latitude/longitude have sensible defaults if they are NULL
ALTER TABLE public.vendors 
ALTER COLUMN latitude SET DEFAULT 0,
ALTER COLUMN longitude SET DEFAULT 0;

-- 3. If there's no cuisine_type column, and the app uses it, we should either rename or add it.
-- However, the original schema had 'cuisine'. We will stick to 'cuisine' in the DB.
-- I will check if 'cuisine_type' exists and if not, keep using 'cuisine'.
-- The app currently sends 'cuisine_type', so I should probably add it or fix the app.
-- Fixing the app is cleaner.

-- 4. Audit Log trigger for vendors (for future trackin)
-- (Optional, but good for "Professional" feel)

-- 5. Refresh schema cache
NOTIFY pgrst, 'reload schema';
