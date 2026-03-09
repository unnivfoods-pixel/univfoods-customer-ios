-- ==========================================
-- 🚨 NUCLEAR DATA RESET & FIX (V11 - FINAL PRO)
-- ==========================================

DO $$ 
BEGIN
    -- 1. ENSURE COLUMNS EXIST (BULLETPROOF)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='products' AND column_name='is_veg') THEN
        ALTER TABLE public.products ADD COLUMN is_veg boolean DEFAULT true;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='products' AND column_name='bestseller') THEN
        ALTER TABLE public.products ADD COLUMN bestseller boolean DEFAULT false;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='products' AND column_name='discount_price') THEN
        ALTER TABLE public.products ADD COLUMN discount_price numeric;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='vendors' AND column_name='cuisine_type') THEN
        ALTER TABLE public.vendors ADD COLUMN cuisine_type text;
    END IF;

    -- 2. DISABLE RLS
    ALTER TABLE public.categories DISABLE ROW LEVEL SECURITY;
    ALTER TABLE public.vendors DISABLE ROW LEVEL SECURITY;
    ALTER TABLE public.products DISABLE ROW LEVEL SECURITY;
    ALTER TABLE public.delivery_zones DISABLE ROW LEVEL SECURITY;
    ALTER TABLE public.user_addresses DISABLE ROW LEVEL SECURITY;
    ALTER TABLE public.user_favorites DISABLE ROW LEVEL SECURITY;
    ALTER TABLE public.orders DISABLE ROW LEVEL SECURITY;

    -- 3. RESET DATA (IN ORDER)
    DELETE FROM public.order_items WHERE TRUE;
    DELETE FROM public.orders WHERE TRUE;
    DELETE FROM public.products WHERE TRUE;
    DELETE FROM public.vendors WHERE TRUE;
    DELETE FROM public.delivery_zones WHERE TRUE;
    DELETE FROM public.categories WHERE TRUE;
END $$;

-- 4. INSERT PREMIUM DATA
-- Zone
INSERT INTO public.delivery_zones (id, name, is_active)
VALUES ('00000000-0000-0000-0000-000000000000', 'Main City', true);

-- Categories
INSERT INTO public.categories (name, image_url, is_active, priority)
VALUES 
('Biryani', 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=500&q=80', true, 100),
('Curry', 'https://images.unsplash.com/photo-1603894584373-5ac82b2ae398?w=500&q=80', true, 90),
('Thali', 'https://images.unsplash.com/photo-1589302168068-964664d93dc0?w=500&q=80', true, 80),
('Pizza', 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=500&q=80', true, 70),
('Burger', 'https://images.unsplash.com/photo-1571091718767-18b5b1457add?w=500&q=80', true, 60);

-- Vendor
INSERT INTO public.vendors (id, name, status, is_active, zone_id, rating, delivery_time, cuisine_type, image_url, address)
VALUES (
    '11111111-1111-1111-1111-111111111111', 
    'Univ Curry Express', 
    'active', 
    true, 
    '00000000-0000-0000-0000-000000000000', 
    4.8, 
    25, 
    'Biryani, Curry, South Indian', 
    'https://images.unsplash.com/photo-1589302168068-964664d93dc0?w=800&q=80',
    'Main Market, Srivilliputhur'
);

-- Products
INSERT INTO public.products (vendor_id, name, price, discount_price, description, is_veg, bestseller, category, image_url)
VALUES 
('11111111-1111-1111-1111-111111111111', 'Chicken Dum Biryani', 280, 240, 'Legendary Hyderabadi dumplings with basmati rice.', false, true, 'Biryani', 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=800&q=80'),
('11111111-1111-1111-1111-111111111111', 'Paneer Butter Masala', 240, 200, 'Soft paneer in a rich, buttery tomato gravy.', true, true, 'Curry', 'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?w=800&q=80'),
('11111111-1111-1111-1111-111111111111', 'Maharaja Thali', 350, NULL, 'A royal spread of curries, dal, rice, and desserts.', true, false, 'Thali', 'https://images.unsplash.com/photo-1546833998-877b37c2e5c6?w=800&q=80'),
('11111111-1111-1111-1111-111111111111', 'Cheese Loaded Burger', 180, 150, 'Gourmet patty with double cheddar and special sauce.', false, false, 'Burger', 'https://images.unsplash.com/photo-1571091718767-18b5b1457add?w=800&q=80');

-- 5. RE-ENABLE REALTIME
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;
