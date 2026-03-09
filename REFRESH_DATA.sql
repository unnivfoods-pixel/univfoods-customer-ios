/*
  REFRESH_DATA.sql
  ----------------
  Use this script to populate the database if the Customer App says "No active vendors found".
  
  Copy and paste this into the Supabase SQL Editor and Click RUN.
*/

-- 1. Clear existing data to avoid duplicates (Optional, but cleaner for demo)
TRUNCATE TABLE public.order_items CASCADE;
TRUNCATE TABLE public.orders CASCADE;
TRUNCATE TABLE public.products CASCADE;
TRUNCATE TABLE public.vendors CASCADE;

-- 2. Insert Vendors (Curry Points)
INSERT INTO public.vendors (name, description, cuisine, rating, status, address, latitude, longitude, image_url, open_time, close_time) 
VALUES 
('Spice Kingdom', 'Authentic North Indian Cuisine', 'North Indian', 4.8, 'Active', '123 Curry Lane, London', 51.5074, -0.1278, 'https://images.unsplash.com/photo-1585937421612-70a008356f36', '10:00', '23:00'),
('Curry House', 'Spicy Chettinad Styles', 'Chettinad', 4.5, 'Active', '45 Spice Market, London', 51.5100, -0.1300, 'https://images.unsplash.com/photo-1565557623262-b51c2513a641', '11:00', '22:00'),
('Tandoori Nights', 'Best Tandoors in town', 'Tandoori', 4.7, 'Active', '88 Clay Oven St, London', 51.5050, -0.1250, 'https://images.unsplash.com/photo-1631452180519-c014fe946bc7', '12:00', '23:30'),
('Dosa Plaza', 'Crispy Dosas and Chutneys', 'South Indian', 4.6, 'Active', '12 Rice Batter Rd, London', 51.5150, -0.1200, 'https://images.unsplash.com/photo-1589301760014-d9296897fba9', '08:00', '22:00');

-- 3. Insert Products (Menu Items)
-- We need to fetch Vendor IDs dynamically or just rely on the order we just inserted (unsafe in prod, safe in single-run script)
-- Using a DO block to insert products for the first vendor found
DO $$
DECLARE
    v_id uuid;
BEGIN
    SELECT id INTO v_id FROM public.vendors WHERE name = 'Spice Kingdom' LIMIT 1;
    
    INSERT INTO public.products (vendor_id, name, description, price, category, image_url, is_available) VALUES
    (v_id, 'Butter Chicken', 'Creamy tomato curry with tender chicken', 12.99, 'Curry', 'https://images.unsplash.com/photo-1603894584373-5ac82b2ae398', true),
    (v_id, 'Garlic Naan', 'Soft bread topped with garlic and butter', 3.50, 'Breads', 'https://images.unsplash.com/photo-1645112411341-6c4fd0237b69', true),
    (v_id, 'Paneer Tikka', 'Grilled cottage cheese cubes', 8.99, 'Starters', 'https://images.unsplash.com/photo-1567188040754-5835e0594991', true);

    SELECT id INTO v_id FROM public.vendors WHERE name = 'Curry House' LIMIT 1;
    
    INSERT INTO public.products (vendor_id, name, description, price, category, image_url, is_available) VALUES
    (v_id, 'Chicken Chettinad', 'Spicy pepper chicken curry', 13.50, 'Curry', 'https://images.unsplash.com/photo-1585937421612-70a008356f36', true),
    (v_id, 'Parotta', 'Flaky layered flatbread', 2.50, 'Breads', 'https://images.unsplash.com/photo-1626074353765-517a681e40be', true);
END $$;
