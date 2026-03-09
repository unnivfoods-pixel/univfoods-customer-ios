-- =========================================================
-- PROMOTIONS & MEDIA MODULE SCHEMA
-- Run this script to enable the centralized Banner system.
-- =========================================================


-- 0. Dependency: Delivery Zones
create table if not exists public.delivery_zones (
  id uuid default gen_random_uuid() primary key,
  created_at timestamp with time zone default timezone('utc'::text, now()),
  name text not null,
  description text,
  active boolean default true
);

-- Enable RLS for zones
alter table public.delivery_zones enable row level security;
create policy "Read zones" on public.delivery_zones for select using (true);
create policy "Admin all zones" on public.delivery_zones for all using (true);

create table if not exists public.banners (
  id uuid default gen_random_uuid() primary key,
  created_at timestamp with time zone default timezone('utc'::text, now()),
  
  -- Core Info
  title text not null,
  image_url text not null,
  description text,
  
  -- Targeting
  target_app text default 'CUSTOMER' check (target_app in ('CUSTOMER', 'VENDOR', 'DELIVERY', 'ADMIN', 'ALL')),
  banner_type text default 'HOME' check (banner_type in ('HOME', 'ZONE', 'CATEGORY', 'VENDOR_PROFILE', 'MENU_ITEM', 'ANNOUNCEMENT', 'POPUP')),
  
  -- Context (Optional links)
  zone_id uuid references public.delivery_zones(id) on delete set null,
  vendor_id uuid references public.vendors(id) on delete set null,
  -- item_id uuid references public.menu_items(id) on delete set null, -- Uncomment if menu_items table exists
  item_id uuid,
  category_id uuid, 
  
  -- Action
  cta_text text,
  cta_type text default 'NONE', -- 'LINK', 'DEEP_LINK', 'NONE'
  cta_value text, -- e.g. '/vendor/123' or 'https://google.com'
  
  -- Rules
  priority integer default 0,
  start_time timestamp with time zone,
  end_time timestamp with time zone,
  is_active boolean default true
);

-- Enable Realtime for instant updates
alter publication supabase_realtime add table public.banners;

-- Security Policies (Public Read, Admin Write)
alter table public.banners enable row level security;

create policy "Enable read access for all users" on public.banners for select using (true);
create policy "Enable all access for admins" on public.banners for all using (true); -- simplified for dev

-- Comments for clarity
comment on column public.banners.target_app is 'Which app should display this banner';
comment on column public.banners.banner_type is 'Where in the app it appears';
