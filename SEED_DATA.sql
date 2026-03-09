-- RUN THIS TO FILL YOUR APP WITH DEMO DATA
-- This creates 1 Restaurant and 5 Menu Items instantly.

INSERT INTO public.vendors (id, name, address, cuisine, status)
VALUES
 ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'Spice Kingdom', '123 Curry Lane', 'Indian', 'Active');

INSERT INTO public.products (vendor_id, name, description, price, category, image_url)
VALUES
 ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'Butter Chicken', 'Rich tomato gravy with tender chicken', 14.99, 'Main', 'https://images.unsplash.com/photo-1603894584373-5ac82b2ae398?auto=format&fit=crop&w=500&q=60'),
 ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'Garlic Naan', 'Oven-baked flatbread with garlic', 3.99, 'Breads', 'https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?auto=format&fit=crop&w=500&q=60'),
 ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'Paneer Tikka', 'Grilled cottage cheese cubes', 12.50, 'Starter', 'https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?auto=format&fit=crop&w=500&q=60'),
 ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'Mango Lassi', 'Sweet yogurt drink', 4.50, 'Drinks', 'https://images.unsplash.com/photo-1544253132-73a7d253f65e?auto=format&fit=crop&w=500&q=60'),
 ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'Chicken Biryani', 'Aromatic rice with spices and chicken', 16.99, 'Rice', 'https://images.unsplash.com/photo-1589302168068-964664d93dc0?auto=format&fit=crop&w=500&q=60');
