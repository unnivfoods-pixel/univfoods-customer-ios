-- Enable public read for vendors
CREATE POLICY "Allow public read for vendors" ON vendors
    FOR SELECT TO public
    USING (true);

-- Enable public read for categories
CREATE POLICY "Allow public read for categories" ON categories
    FOR SELECT TO public
    USING (true);

-- Enable public read for banners
CREATE POLICY "Allow public read for banners" ON banners
    FOR SELECT TO public
    USING (true);

-- Enable Realtime for these tables just in case
ALTER PUBLICATION supabase_realtime ADD TABLE vendors;
ALTER PUBLICATION supabase_realtime ADD TABLE categories;
ALTER PUBLICATION supabase_realtime ADD TABLE banners;
