-- 🌶️ BOUTIQUE ENHANCEMENT: SPICE ARCHITECTURE
-- Run this in Supabase SQL Editor

-- 1. Add spice_level to products table
ALTER TABLE public.products 
ADD COLUMN IF NOT EXISTS spice_level text DEFAULT 'Medium';

-- 2. Add signature_asset toggle for premium labeling
ALTER TABLE public.products 
ADD COLUMN IF NOT EXISTS is_signature boolean DEFAULT false;

-- 3. Update existing assets with default status
UPDATE public.products SET spice_level = 'Medium' WHERE spice_level IS NULL;
UPDATE public.products SET is_signature = false WHERE is_signature IS NULL;

-- 4. Enable Realtime for these new columns (implicit via table alter, but confirming)
NOTIFY pgrst, 'reload schema';
