-- ==========================================
-- 🚀 ULTIMATE REALTIME DATA & SCHEMA FIX
-- ==========================================

-- 1. ENSURE SCHEMAS ARE CORRECT
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='vendors' AND column_name='status') THEN
        ALTER TABLE public.vendors ADD COLUMN status text DEFAULT 'active';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='vendors' AND column_name='zone_id') THEN
        ALTER TABLE public.vendors ADD COLUMN zone_id uuid;
    END IF;
END $$;

-- 2. ENSURE AT LEAST ONE ZONE EXISTS (CRITICAL TO PREVENT CRASH)
INSERT INTO public.delivery_zones (id, name, is_active)
SELECT '00000000-0000-0000-0000-000000000000', 'Main City', true
WHERE NOT EXISTS (SELECT 1 FROM public.delivery_zones LIMIT 1)
ON CONFLICT DO NOTHING;

-- 3. ENSURE SOME CATEGORIES EXIST
INSERT INTO public.categories (name, image_url, is_active, priority)
VALUES 
('Biryani', 'https://img.freepik.com/free-photo/gourmet-chicken-biryani-with-steaming-basmati-rice-generated-by-ai_188544-15525.jpg', true, 10),
('Burger', 'https://img.freepik.com/free-photo/delicious-quality-burger-with-vegetables_23-2150867844.jpg', true, 9),
('Pizza', 'https://img.freepik.com/free-photo/fresh-baked-pizza-with-tasty-toppings-generated-by-ai_188544-15411.jpg', true, 8),
('North Indian', 'https://img.freepik.com/free-photo/traditional-indian-food-thali-with-dal-flatbread-rice-chicken-curry_123827-21783.jpg', true, 7),
('South Indian', 'https://img.freepik.com/free-photo/south-indian-food-dosa-idli-sambhar-chutney-white-background_123827-21764.jpg', true, 6)
ON CONFLICT DO NOTHING;

-- 4. FIX ALL VENDORS TO BE VISIBLE
UPDATE public.vendors 
SET status = 'active', 
    is_active = true,
    zone_id = (SELECT id FROM public.delivery_zones LIMIT 1)
WHERE status IS NULL OR status = '' OR zone_id IS NULL;

-- 5. ENABLE REALTIME FOR EVERYTHING
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow Public Read Categories" ON public.categories;
CREATE POLICY "Allow Public Read Categories" ON public.categories FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow Public Read Vendors" ON public.vendors;
CREATE POLICY "Allow Public Read Vendors" ON public.vendors FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow Public Read Products" ON public.products;
CREATE POLICY "Allow Public Read Products" ON public.products FOR SELECT USING (true);

-- Check publication again
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime' AND puballtables = true) THEN
        BEGIN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.categories;
            ALTER PUBLICATION supabase_realtime ADD TABLE public.vendors;
            ALTER PUBLICATION supabase_realtime ADD TABLE public.products;
        EXCEPTION WHEN others THEN RAISE NOTICE 'Realtime tables already added';
        END;
    END IF;
END $$;
