-- Add missing real-time action columns to vendors table
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS is_pure_veg BOOLEAN DEFAULT false;
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS has_offers BOOLEAN DEFAULT false;

-- Mirror cuisine to cuisine_type if not exists to support both apps
DO $$ 
BEGIN 
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='vendors' AND column_name='cuisine_type') THEN
    ALTER TABLE public.vendors ADD COLUMN cuisine_type TEXT;
  END IF;
END $$;

UPDATE public.vendors SET is_pure_veg = true WHERE name ILIKE '%veg%';
UPDATE public.vendors SET has_offers = true WHERE name ILIKE '%curry house%';
