-- FIX ORDER SCHEMA
-- This adds missing columns to the 'orders' table to support the new Checkout features.

-- 1. Add delivery_address column (Text)
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS delivery_address TEXT;

-- 2. Add special_instructions (Notes)
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS special_instructions TEXT;

-- 3. Add promo_code
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS promo_code TEXT;

-- 4. Add breakdown columns if missing
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS item_total DOUBLE PRECISION DEFAULT 0;

ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS delivery_fee DOUBLE PRECISION DEFAULT 0;

ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS platform_fee DOUBLE PRECISION DEFAULT 0;

ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS gst DOUBLE PRECISION DEFAULT 0;

ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS tip_amount DOUBLE PRECISION DEFAULT 0;

-- 5. Refresh schema cache (Supabase does this automatically usually, but good to know)
NOTIFY pgrst, 'reload schema';
