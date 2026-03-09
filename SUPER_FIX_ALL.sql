-- ========================================================
-- SUPER FIX SCRIPT V2 (ERROR PROOF)
-- Run this in Supabase SQL Editor to fix EVERYTHING.
-- ========================================================

-- PART 1: FIX MISSING COLUMNS
-- This adds the missing 'is_veg' column so you can save items.
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS is_veg boolean DEFAULT true;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS rating numeric DEFAULT 0;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS votes integer DEFAULT 0;

-- PART 2: FIX BANNERS & CATEGORIES TABLES
CREATE TABLE IF NOT EXISTS public.categories (
    id uuid default gen_random_uuid() primary key,
    created_at timestamp with time zone default timezone('utc'::text, now()),
    name text not null,
    image_url text,
    priority integer default 0,
    is_active boolean default true
);

CREATE TABLE IF NOT EXISTS public.banners (
  id uuid default gen_random_uuid() primary key,
  created_at timestamp with time zone default timezone('utc'::text, now()),
  title text not null,
  image_url text,
  description text,
  target_app text default 'CUSTOMER',
  banner_type text default 'HOME',
  zone_id uuid,
  vendor_id uuid,
  product_id uuid,
  priority integer default 0,
  start_time timestamp with time zone,
  end_time timestamp with time zone,
  is_active boolean default true,
  cta_value text
);

-- PART 3: NUCLEAR RLS FIX (Access Denied Fix)
-- This destroys existing restrictions and allows the Admin Panel to work freely.

-- Products Table
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public products read" ON public.products;
DROP POLICY IF EXISTS "Enable all access for products" ON public.products;
DROP POLICY IF EXISTS "Super Access Products" ON public.products;
CREATE POLICY "Super Access Products" ON public.products FOR ALL USING (true) WITH CHECK (true);

-- Vendors Table
ALTER TABLE public.vendors ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Enable all access for vendors" ON public.vendors;
DROP POLICY IF EXISTS "Super Access Vendors" ON public.vendors;
CREATE POLICY "Super Access Vendors" ON public.vendors FOR ALL USING (true) WITH CHECK (true);

-- Orders Table
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Enable all access for orders" ON public.orders;
DROP POLICY IF EXISTS "Super Access Orders" ON public.orders;
CREATE POLICY "Super Access Orders" ON public.orders FOR ALL USING (true) WITH CHECK (true);

-- Banners & Categories
ALTER TABLE public.banners ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Enable all access for banners" ON public.banners;
CREATE POLICY "Enable all access for banners" ON public.banners FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Enable all access for categories" ON public.categories;
CREATE POLICY "Enable all access for categories" ON public.categories FOR ALL USING (true) WITH CHECK (true);

-- PART 4: ENABLE REALTIME (Now with Error Handling!)
DO $$
BEGIN
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.products; EXCEPTION WHEN duplicate_object THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.vendors; EXCEPTION WHEN duplicate_object THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.orders; EXCEPTION WHEN duplicate_object THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.banners; EXCEPTION WHEN duplicate_object THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.categories; EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;

-- PART 5: REFRESH CACHE
NOTIFY pgrst, 'reload schema';
