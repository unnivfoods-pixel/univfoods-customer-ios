-- ==========================================
-- 1. BASIC TABLES (Vendors, Products, Orders)
-- ==========================================

-- Enable PostGIS for location features
create extension if not exists postgis;

-- 1. Vendors (Curry Points) Table
create table public.vendors (
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

-- 2. Products (Menu Items) Table
create table public.products (
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

-- 3. Orders Table
create table public.orders (
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

-- 4. Enable Realtime for Basic Tables
alter publication supabase_realtime add table public.vendors;
alter publication supabase_realtime add table public.orders;
alter publication supabase_realtime add table public.products;

-- 5. Security Policies for Basic Tables
alter table public.vendors enable row level security;
alter table public.products enable row level security;
alter table public.orders enable row level security;

create policy "Public read" on public.vendors for select using (true);
create policy "Public products read" on public.products for select using (true);
create policy "Authenticated insert" on public.vendors for insert with check (auth.role() = 'authenticated');
create policy "Authenticated update" on public.vendors for update using (auth.role() = 'authenticated');
create policy "Public orders insert" on public.orders for insert with check (true);
create policy "Public orders select" on public.orders for select using (true);


-- ==========================================
-- 2. ADMIN FEATURES (Riders, Settings, Profiles)
-- ==========================================

-- 1. Delivery Riders Table
create table if not exists public.delivery_riders (
  id uuid default gen_random_uuid() primary key,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  name text not null,
  phone text,
  status text default 'Offline', -- Online, Offline, Busy
  current_order_id uuid references public.orders(id),
  latitude double precision,
  longitude double precision,
  total_deliveries integer default 0,
  rating numeric default 5.0
);

-- 2. App Settings Table
create table if not exists public.app_settings (
  key text primary key,
  value jsonb not null,
  updated_at timestamp with time zone default timezone('utc'::text, now())
);

-- 3. Customer Profiles (Mirror of Auth Users)
create table if not exists public.customer_profiles (
  id uuid references auth.users(id) primary key,
  email text,
  full_name text,
  phone text,
  avatar_url text,
  created_at timestamp with time zone default timezone('utc'::text, now())
);

-- 4. Enable Realtime for Admin Tables
alter publication supabase_realtime add table public.delivery_riders;
alter publication supabase_realtime add table public.app_settings;
alter publication supabase_realtime add table public.customer_profiles;

-- 5. Policies for Admin Tables
alter table public.delivery_riders enable row level security;
alter table public.app_settings enable row level security;
alter table public.customer_profiles enable row level security;

-- Allow public read for now (for Admin & Apps)
create policy "Public riders read" on public.delivery_riders for select using (true);
create policy "Public riders insert" on public.delivery_riders for insert with check (true);
create policy "Public riders update" on public.delivery_riders for update using (true);

create policy "Public settings read" on public.app_settings for select using (true);
create policy "Public settings update" on public.app_settings for update using (true);
create policy "Public settings insert" on public.app_settings for insert with check (true);

create policy "Public profiles read" on public.customer_profiles for select using (true);
create policy "Users can update own profile" on public.customer_profiles for update using (auth.uid() = id);
create policy "Users can insert own profile" on public.customer_profiles for insert with check (auth.uid() = id);

-- 6. Trigger to auto-create profile on signup
create or replace function public.handle_new_user() 
returns trigger as $$
begin
  insert into public.customer_profiles (id, email, full_name, phone)
  values (new.id, new.email, new.raw_user_meta_data->>'full_name', new.phone);
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Seed Data (Riders)
insert into public.delivery_riders (name, phone, status, latitude, longitude)
values 
('Raju Kumar', '+91 9876543210', 'Online', 17.3850, 78.4867),
('Vikram Singh', '+91 9123456780', 'Busy', 17.4401, 78.3489),
('Amit Sharma', '+91 9988776655', 'Offline', 17.3616, 78.4747);

-- Seed Data (Settings)
insert into public.app_settings (key, value) values 
('platform_config', '{"name": "UNIV Foods", "currency": "INR", "tax_rate": 5, "delivery_fee": 40}'::jsonb)
on conflict (key) do nothing;
