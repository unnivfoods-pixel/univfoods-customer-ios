-- Protocol: Enable Real-time for Vendor App Core Tables
-- Execute this in the Supabase SQL Editor (Removes syntax errors)

-- 1. Enable Real-time for specific tables
ALTER publication supabase_realtime ADD TABLE public.vendors;
ALTER publication supabase_realtime ADD TABLE public.orders;
ALTER publication supabase_realtime ADD TABLE public.products;

-- 2. Ensure Vendor status columns exist and are optimized
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'Open';
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;

-- 3. Ensure Cuisine mirroring for multiple app versions
DO $$ 
BEGIN 
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='vendors' AND column_name='cuisine_type') THEN
    ALTER TABLE public.vendors ADD COLUMN cuisine_type TEXT;
  END IF;
END $$;

-- 4. Set row level security (RLS) to allow vendors to manage their own data
-- Note: Assuming you have owner_id column linked to auth.uid()
ALTER TABLE public.vendors ENABLE ROW LEVEL SECURITY;

-- 5. Helper update to populate cuisine_type if empty
UPDATE public.vendors SET cuisine_type = 'Indian' WHERE cuisine_type IS NULL;
