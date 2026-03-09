-- Ensure Delivery Zones have data and correct active column
DO $$ 
BEGIN
    if not exists (select 1 from information_schema.columns where table_name='delivery_zones' and column_name='is_active') then
        alter table public.delivery_zones rename column active to is_active;
    end if;
END $$;

-- Seed a zone if none exists
INSERT INTO public.delivery_zones (name, city, is_active, coordinates)
SELECT 'Main City', 'Hyderabad', true, '[{"lat": 17.385, "lng": 78.486}]'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM public.delivery_zones);

-- Also fix vendors table columns for the manual mapping
ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS image_url text,
ADD COLUMN IF NOT EXISTS banner_url text,
ADD COLUMN IF NOT EXISTS sub_banner_url text,
ADD COLUMN IF NOT EXISTS gallery_images text[] DEFAULT '{}'::text[],
ADD COLUMN IF NOT EXISTS commission_rate numeric DEFAULT 15,
ADD COLUMN IF NOT EXISTS payout_cycle text DEFAULT 'Weekly',
ADD COLUMN IF NOT EXISTS is_verified boolean DEFAULT true,
ADD COLUMN IF NOT EXISTS zone_id uuid,
ADD COLUMN IF NOT EXISTS is_trending boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS is_top_rated boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS is_pure_veg boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS tags text[] DEFAULT '{}'::text[],
ADD COLUMN IF NOT EXISTS email text;

-- Update rls
ALTER TABLE public.vendors ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Enable all admin" ON public.vendors;
CREATE POLICY "Enable all admin" ON public.vendors FOR ALL USING (true);
