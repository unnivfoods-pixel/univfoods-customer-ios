-- ==========================================
-- 🚀 SUPER DATABASE RECOVERY & STABILITY FIX (V3)
-- This script fixes "Blank Pages" by enabling access and categories.
-- ==========================================

-- 1. FIX PERMISSIONS (MOST IMPORTANT)
-- These allow the app to SEE the food and categories.
ALTER TABLE IF EXISTS public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.vendors ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.delivery_zones ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public read categories" ON public.categories;
CREATE POLICY "Allow public read categories" ON public.categories FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow public read vendors" ON public.vendors;
CREATE POLICY "Allow public read vendors" ON public.vendors FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow public read products" ON public.products;
CREATE POLICY "Allow public read products" ON public.products FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow public read zones" ON public.delivery_zones;
CREATE POLICY "Allow public read zones" ON public.delivery_zones FOR SELECT USING (true);

-- 2. ENSURE CATEGORIES EXIST (The App stays blank if these are missing)
-- We use a DO block to insert safely without ON CONFLICT errors
DO $$
BEGIN
    -- Biryani
    IF NOT EXISTS (SELECT 1 FROM public.categories WHERE name = 'Biryani') THEN
        INSERT INTO public.categories (name, image_url, priority)
        VALUES ('Biryani', 'https://img.freepik.com/free-photo/gourmet-chicken-biryani-with-steaming-basmati-rice-generated-by-ai_188544-15525.jpg', 10);
    END IF;

    -- Burger
    IF NOT EXISTS (SELECT 1 FROM public.categories WHERE name = 'Burger') THEN
        INSERT INTO public.categories (name, image_url, priority)
        VALUES ('Burger', 'https://img.freepik.com/free-photo/delicious-quality-burger-with-vegetables_23-2150867844.jpg', 9);
    END IF;

    -- Pizza
    IF NOT EXISTS (SELECT 1 FROM public.categories WHERE name = 'Pizza') THEN
        INSERT INTO public.categories (name, image_url, priority)
        VALUES ('Pizza', 'https://img.freepik.com/free-photo/fresh-baked-pizza-with-tasty-toppings-generated-by-ai_188544-15411.jpg', 8);
    END IF;

    -- North Indian
    IF NOT EXISTS (SELECT 1 FROM public.categories WHERE name = 'North Indian') THEN
        INSERT INTO public.categories (name, image_url, priority)
        VALUES ('North Indian', 'https://img.freepik.com/free-photo/traditional-indian-food-thali-with-dal-flatbread-rice-chicken-curry_123827-21783.jpg', 7);
    END IF;

    -- South Indian
    IF NOT EXISTS (SELECT 1 FROM public.categories WHERE name = 'South Indian') THEN
        INSERT INTO public.categories (name, image_url, priority)
        VALUES ('South Indian', 'https://img.freepik.com/free-photo/south-indian-food-dosa-idli-sambhar-chutney-white-background_123827-21764.jpg', 6);
    END IF;
END $$;

-- 3. ENSURE VENDOR & PRODUCTS EXIST
DO $$
BEGIN
    -- Check for the special vendor
    IF NOT EXISTS (SELECT 1 FROM public.vendors WHERE name = 'UNIV Special Curry') THEN
        -- Insert a default zone first if missing
        IF NOT EXISTS (SELECT 1 FROM public.delivery_zones LIMIT 1) THEN
            INSERT INTO public.delivery_zones (id, name, is_active)
            VALUES ('00000000-0000-0000-0000-000000000001', 'Default Zone', true);
        END IF;

        INSERT INTO public.vendors (id, name, cuisine_type, rating, delivery_time, cost_for_two, status, image_url)
        VALUES (
            '11111111-1111-1111-1111-111111111111', 
            'UNIV Special Curry', 
            'Curry, North Indian, South Indian', 
            4.8, 25, 200, 'active',
            'https://img.freepik.com/free-photo/chicken-curry-with-rice_144627-25164.jpg'
        );

        -- Add some products to it
        INSERT INTO public.products (vendor_id, name, price, category, is_available)
        VALUES 
        ('11111111-1111-1111-1111-111111111111', 'Butter Chicken', 250, 'North Indian', true),
        ('11111111-1111-1111-1111-111111111111', 'Paneer Tikka', 180, 'North Indian', true);
    END IF;
END $$;

-- 4. ENABLE REALTIME
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;
