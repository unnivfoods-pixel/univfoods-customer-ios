-- 1. Create Categories Table
CREATE TABLE IF NOT EXISTS public.categories (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    image_url TEXT,
    priority INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- 2. Add columns to Banners if they don't exist
ALTER TABLE public.banners ADD COLUMN IF NOT EXISTS product_id UUID REFERENCES public.products(id) ON DELETE SET NULL;
ALTER TABLE public.banners ADD COLUMN IF NOT EXISTS description TEXT;

-- 3. Enable Realtime for Categories
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'categories') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.categories;
  END IF;
END $$;

-- 4. Enable RLS for Categories
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public Read Categories" ON public.categories;
CREATE POLICY "Public Read Categories" ON public.categories FOR SELECT USING (true);
DROP POLICY IF EXISTS "Admin All Categories" ON public.categories;
CREATE POLICY "Admin All Categories" ON public.categories FOR ALL USING (true);

-- 5. Seed initial categories
INSERT INTO public.categories (name, image_url, priority)
VALUES 
('Trending', 'https://img.icons8.com/color/96/fire-element.png', 10),
('Curry', 'https://img.icons8.com/color/96/curry.png', 9),
('Breads', 'https://img.icons8.com/color/96/naan.png', 8),
('Pure Veg', 'https://img.icons8.com/color/96/leaf.png', 7),
('Top Rated', 'https://img.icons8.com/color/96/star.png', 6)
ON CONFLICT (name) DO NOTHING;
