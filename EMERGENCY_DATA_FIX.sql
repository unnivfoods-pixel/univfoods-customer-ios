-- 🔥 EMERGENCY ACCESS RESTORATION 🔥
-- This script nukes RLS on critical tables to ensure the landing page and apps can at least READ data.

BEGIN;

-- 1. DISABLE RLS ON PRODUCTS (TEMPORARY FOR RESTORATION)
ALTER TABLE public.products DISABLE ROW LEVEL SECURITY;

-- 2. ENSURE PUBLIC READ POLICY EXISTS (IN CASE WE RE-ENABLE)
DROP POLICY IF EXISTS "Public View" ON public.products;
CREATE POLICY "Public View" ON public.products FOR SELECT USING (true);

-- 3. FIX VENDORS RLS (MUST BE READABLE FOR JOINS)
ALTER TABLE public.vendors DISABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public View" ON public.vendors;
CREATE POLICY "Public View" ON public.vendors FOR SELECT USING (true);

-- 4. FIX REGISTRATION REQUESTS (MUST BE WRITABLE FROM LANDING PAGE)
ALTER TABLE public.registration_requests DISABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public Insert" ON public.registration_requests;
CREATE POLICY "Public Insert" ON public.registration_requests FOR INSERT WITH CHECK (true);

-- 5. VERIFY PRODUCTS EXIST
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.products) THEN
        INSERT INTO public.products (name, category, price, is_veg, is_available, image_url)
        VALUES 
        ('Gourmet Paneer Tikka', 'Starter', 249, true, true, 'https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?w=800'),
        ('Signature Butter Chicken', 'Main', 380, false, true, 'https://images.unsplash.com/photo-1603894584373-5ac82b2ae398?w=800'),
        ('Saffron Basmati Rice', 'Main', 180, true, true, 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=800');
    END IF;
END $$;

COMMIT;
