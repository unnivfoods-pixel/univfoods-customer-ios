-- =========================================================================
-- COMPLETE DATABASE SETUP (FIXED VERSION 2)
-- Copy EVERYTHING in this file and paste it into the Supabase SQL Editor.
-- =========================================================================

-- 1. EXTENSIONS
create extension if not exists postgis;

-- 2. TABLES

-- Vendors
create table if not exists public.vendors (
  id uuid default gen_random_uuid() primary key,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  name text not null,
  address text,
  phone text,
  manager text,
  cuisine text,
  open_time text,
  close_time text,
  latitude double precision,
  longitude double precision,
  rating numeric default 5.0,
  status text default 'Active',
  review_count integer default 0,
  owner_id uuid references auth.users(id)
);

-- Products
create table if not exists public.products (
  id uuid default gen_random_uuid() primary key,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  vendor_id uuid references public.vendors(id) not null,
  name text not null,
  description text,
  price numeric not null,
  image_url text,
  is_available boolean default true,
  category text
);

-- Orders
create table if not exists public.orders (
  id uuid default gen_random_uuid() primary key,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  customer_id uuid references auth.users(id),
  vendor_id uuid references public.vendors(id),
  total numeric not null,
  status text default 'Pending',
  items jsonb,
  delivery_lat double precision,
  delivery_long double precision
);

-- Delivery Zones
create table if not exists public.delivery_zones (
  id uuid default gen_random_uuid() primary key,
  created_at timestamp with time zone default timezone('utc'::text, now()),
  name text not null,
  description text,
  active boolean default true
);

-- Banners
create table if not exists public.banners (
  id uuid default gen_random_uuid() primary key,
  created_at timestamp with time zone default timezone('utc'::text, now()),
  title text not null,
  image_url text not null,
  description text,
  target_app text default 'CUSTOMER', 
  banner_type text default 'HOME',
  zone_id uuid references public.delivery_zones(id) on delete set null,
  vendor_id uuid references public.vendors(id) on delete set null,
  item_id uuid,
  category_id uuid, 
  cta_text text,
  cta_type text default 'NONE',
  cta_value text,
  priority integer default 0,
  start_time timestamp with time zone,
  end_time timestamp with time zone,
  is_active boolean default true
);

-- 3. ENABLE REALTIME
-- Using DO blocks to safely ignore errors if tables are already in publication
do $$
begin
  alter publication supabase_realtime add table public.vendors;
exception when others then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.products;
exception when others then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.orders;
exception when others then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.banners;
exception when others then null;
end $$;

-- 4. SECURITY (RLS)
alter table public.vendors enable row level security;
alter table public.products enable row level security;
alter table public.orders enable row level security;
alter table public.delivery_zones enable row level security;
alter table public.banners enable row level security;

-- POLICIES
-- Using DO blocks to avoid "policy already exists" errors
do $$
begin
  create policy "Public read vendors" on public.vendors for select using (true);
exception when others then null;
end $$;

do $$
begin
  create policy "Authenticated insert vendors" on public.vendors for insert with check (auth.role() = 'authenticated');
exception when others then null;
end $$;

do $$
begin
  create policy "Authenticated update vendors" on public.vendors for update using (auth.role() = 'authenticated');
exception when others then null;
end $$;

do $$
begin
  create policy "Public read products" on public.products for select using (true);
exception when others then null;
end $$;

do $$
begin
  create policy "Public insert orders" on public.orders for insert with check (true);
exception when others then null;
end $$;

do $$
begin
  create policy "Public select orders" on public.orders for select using (true);
exception when others then null;
end $$;

do $$
begin
  create policy "Public read zones" on public.delivery_zones for select using (true);
exception when others then null;
end $$;

do $$
begin
  create policy "Public read banners" on public.banners for select using (true);
exception when others then null;
end $$;

do $$
begin
  create policy "Admin all banners" on public.banners for all using (true);
exception when others then null;
end $$;

do $$
begin
  create policy "Admin all zones" on public.delivery_zones for all using (true);
exception when others then null;
end $$;
