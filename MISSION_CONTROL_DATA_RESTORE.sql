-- 🛰️ MISSION CONTROL: DATA RESTORATION & PULSE REPAIR (V4 - ULTRA STABLE)
-- Run this script in the Supabase SQL Editor if data is missing or intermittent.

BEGIN;

-- 1. NUCLEAR RLS PERMISSIONS (Ensure Dashboard can see EVERYTHING)
-- We enable RLS and add "Allow All" policies for the Admin context.

DO $$ 
DECLARE
    t text;
BEGIN
    FOR t IN 
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_type = 'BASE TABLE'
        -- 🚨 EXCLUDE SYSTEM & EXTENSION TABLES
        AND table_name NOT IN ('spatial_ref_sys', 'geography_columns', 'geometry_columns', 'raster_columns', 'raster_overviews')
    LOOP
        EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
        EXECUTE format('DROP POLICY IF EXISTS "Admin Shadow Access %I" ON public.%I', t, t);
        EXECUTE format('CREATE POLICY "Admin Shadow Access %I" ON public.%I FOR ALL USING (true) WITH CHECK (true)', t, t);
    END LOOP;
END $$;

-- 2. FORCE INSERT MISSION-CRITICAL DATA (Using safe existence checks)
-- This ensures the "Vault" is never empty.

-- Categories
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.categories WHERE name = 'North Indian') THEN
        INSERT INTO public.categories (name, image_url, priority)
        VALUES ('North Indian', 'https://images.unsplash.com/photo-1585937421612-70a008356fbe?auto=format&fit=crop&w=800&q=80', 10);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.categories WHERE name = 'South Indian') THEN
        INSERT INTO public.categories (name, image_url, priority)
        VALUES ('South Indian', 'https://images.unsplash.com/photo-1630383249896-424e482df921?auto=format&fit=crop&w=800&q=80', 9);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.categories WHERE name = 'Beverages') THEN
        INSERT INTO public.categories (name, image_url, priority)
        VALUES ('Beverages', 'https://images.unsplash.com/photo-1544145945-f904253db0ad?auto=format&fit=crop&w=800&q=80', 8);
    END IF;
END $$;

-- Vendors (Demo Nodes)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.vendors WHERE id = 'd0000000-0000-0000-0000-000000000001') THEN
        INSERT INTO public.vendors (id, name, cuisine_type, status, latitude, longitude, rating, address, manager, pending_payout)
        VALUES ('d0000000-0000-0000-0000-000000000001', 'Signature Curry House', 'North Indian', 'ONLINE', 9.5100, 77.6300, 4.9, 'Mission Control Center, Srivilliputhur', 'System Admin', 12500);
    ELSE
        UPDATE public.vendors SET status = 'ONLINE' WHERE id = 'd0000000-0000-0000-0000-000000000001';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.vendors WHERE id = 'd0000000-0000-0000-0000-000000000002') THEN
        INSERT INTO public.vendors (id, name, cuisine_type, status, latitude, longitude, rating, address, manager, pending_payout)
        VALUES ('d0000000-0000-0000-0000-000000000002', 'Dosa Dynamic', 'South Indian', 'ONLINE', 9.5150, 77.6380, 4.8, 'East Tech Park', 'System Admin', 8400);
    ELSE
        UPDATE public.vendors SET status = 'ONLINE' WHERE id = 'd0000000-0000-0000-0000-000000000002';
    END IF;
END $$;

-- Products (Signature Items)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.products WHERE name = 'Butter Chicken Deluxe') THEN
        INSERT INTO public.products (vendor_id, name, price, category, is_veg, is_available, image_url)
        VALUES ('d0000000-0000-0000-0000-000000000001', 'Butter Chicken Deluxe', 320, 'North Indian', false, true, 'https://images.unsplash.com/photo-1588166524941-3bf61a9c41db?auto=format&fit=crop&w=800&q=80');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.products WHERE name = 'Dal Makhani Gold') THEN
        INSERT INTO public.products (vendor_id, name, price, category, is_veg, is_available, image_url)
        VALUES ('d0000000-0000-0000-0000-000000000001', 'Dal Makhani Gold', 240, 'North Indian', true, true, 'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?auto=format&fit=crop&w=800&q=80');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.products WHERE name = 'Ghee Roast Special') THEN
        INSERT INTO public.products (vendor_id, name, price, category, is_veg, is_available, image_url)
        VALUES ('d0000000-0000-0000-0000-000000000002', 'Ghee Roast Special', 160, 'South Indian', true, true, 'https://images.unsplash.com/photo-1630383249896-424e482df921?auto=format&fit=crop&w=800&q=80');
    END IF;
END $$;

-- 3. RESET REPLICA IDENTITY (The Realtime Engine)
ALTER TABLE public.vendors REPLICA IDENTITY FULL;
ALTER TABLE public.products REPLICA IDENTITY FULL;
ALTER TABLE public.orders REPLICA IDENTITY FULL;
ALTER TABLE public.customer_profiles REPLICA IDENTITY FULL;

-- 4. RECREATE PUBLICATION
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

COMMIT;

-- 5. RELOAD SCHEMA CACHE
NOTIFY pgrst, 'reload schema';
