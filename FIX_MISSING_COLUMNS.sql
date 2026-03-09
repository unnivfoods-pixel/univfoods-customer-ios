-- ==========================================
-- FIX MISSING COLUMNS IN DATABASE
-- Run this script to fix the "Could not find 'is_veg' column" error
-- ==========================================

-- 1. Add 'is_veg' column to products table
ALTER TABLE public.products 
ADD COLUMN IF NOT EXISTS is_veg boolean DEFAULT true;

-- 2. Add 'rating' column to products (good to have for future)
ALTER TABLE public.products 
ADD COLUMN IF NOT EXISTS rating numeric DEFAULT 0;

-- 3. Add 'votes' column to products
ALTER TABLE public.products 
ADD COLUMN IF NOT EXISTS votes integer DEFAULT 0;

-- 4. Refresh schema cache
NOTIFY pgrst, 'reload schema';
