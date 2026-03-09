-- ==========================================
-- 🛡️ RECOVERY DATA (RESTORE FROM IMAGES)
-- ==========================================

DO $$ 
BEGIN
    -- 1. Ensure columns exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='products' AND column_name='is_veg') THEN
        ALTER TABLE public.products ADD COLUMN is_veg boolean DEFAULT true;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='products' AND column_name='category') THEN
        ALTER TABLE public.products ADD COLUMN category text;
    END IF;

    -- 2. Restore Delivery Zone
    INSERT INTO public.delivery_zones (id, name, is_active)
    VALUES ('00000000-0000-0000-0000-000000000000', 'Srivilliputhur', true)
    ON CONFLICT (id) DO NOTHING;

    -- 3. Restore Vendors from Images
    INSERT INTO public.vendors (id, name, status, is_active, zone_id, rating, delivery_time, cuisine_type, image_url, address)
    VALUES 
    (
        '11111111-1111-1111-1111-111111111111', 
        'UNIV Special Curry', 
        'active', 
        true, 
        '00000000-0000-0000-0000-000000000000', 
        4.8, 
        25, 
        'Curry, North Indian, South Indian', 
        'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=800',
        'Main Roat, Srivilliputhur'
    ),
    (
        '22222222-2222-2222-2222-222222222222', 
        'Srivilliputhur Curry Point', 
        'active', 
        true, 
        '00000000-0000-0000-0000-000000000000', 
        4.8, 
        25, 
        'Curry, North Indian, South Indian', 
        'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=800',
        'Main Roat, Srivilliputhur'
    )
    ON CONFLICT (id) DO NOTHING;

    -- 4. Restore Products from Images
    INSERT INTO public.products (vendor_id, name, price, description, is_veg, category, image_url)
    VALUES 
    ('11111111-1111-1111-1111-111111111111', 'potato', 50, 'Freshly cooked potato curry.', true, 'Curry', 'https://images.unsplash.com/photo-1518977676601-b53f02ac10dd?w=400'),
    ('11111111-1111-1111-1111-111111111111', 'Egg Curry', 50, 'Spicy boiled egg curry.', false, 'Main', 'https://images.unsplash.com/photo-1542367533-5132153b7491?w=400'),
    ('11111111-1111-1111-1111-111111111111', 'Paneer', 50, 'Soft paneer in rich gravy.', true, 'Main', 'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?w=400'),
    ('11111111-1111-1111-1111-111111111111', 'Chicken Curry', 120, 'Tender chicken in aromatic spices.', false, 'Main', 'https://images.unsplash.com/photo-1603894584373-5ac82b2ae398?w=400')
    ON CONFLICT (id) DO NOTHING;

    -- 5. Restore Categories
    INSERT INTO public.categories (name, image_url, is_active, priority)
    VALUES 
    ('Biryani', 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=200', true, 100),
    ('Burger', 'https://images.unsplash.com/photo-1571091718767-18b5b1457add?w=200', true, 90),
    ('Pizza', 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=200', true, 80),
    ('North Indian', 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=200', true, 70),
    ('South Indian', 'https://images.unsplash.com/photo-1589302168068-964664d93dc0?w=200', true, 60)
    ON CONFLICT (id) DO NOTHING;

END $$;
