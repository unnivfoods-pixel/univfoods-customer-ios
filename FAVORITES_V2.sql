-- Add product_id support to favorites
ALTER TABLE public.user_favorites ADD COLUMN IF NOT EXISTS product_id UUID REFERENCES public.products(id);

-- Update unique constraint to allow multiple favorites per user (one for vendor, one for product)
-- First drop old unique constraint (often named user_favorites_user_id_vendor_id_key)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'user_favorites_user_id_vendor_id_key') THEN
        ALTER TABLE public.user_favorites DROP CONSTRAINT user_favorites_user_id_vendor_id_key;
    END IF;
END $$;

-- Add new unique constraint
ALTER TABLE public.user_favorites ADD CONSTRAINT unique_user_fave UNIQUE (user_id, vendor_id, product_id);
