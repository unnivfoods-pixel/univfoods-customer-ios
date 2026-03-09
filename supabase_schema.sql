-- Enable PostGIS for location features (optional but good for future "nearby" queries)
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
  status text default 'Active', -- 'Active', 'Inactive'
  review_count integer default 0,
  owner_id uuid references auth.users(id) -- Link to Supabase Auth User
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
  category text -- 'Starter', 'Main', 'Rice', etc.
);

-- 3. Orders Table
create table public.orders (
  id uuid default gen_random_uuid() primary key,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  customer_id uuid references auth.users(id), -- If logged in
  vendor_id uuid references public.vendors(id),
  total numeric not null,
  status text default 'Pending', -- 'Pending', 'Preparing', 'Ready', 'Out for Delivery', 'Delivered'
  items jsonb, -- Store items as JSON snapshot: [{name: "Curry", qty: 1, price: 10}]
  delivery_lat double precision,
  delivery_long double precision
);

-- 4. Enable Realtime for these tables
alter publication supabase_realtime add table public.vendors;
alter publication supabase_realtime add table public.orders;
alter publication supabase_realtime add table public.products;

-- 5. Row Level Security (RLS) policies (Basic for MVP)
alter table public.vendors enable row level security;
alter table public.products enable row level security;
alter table public.orders enable row level security;

-- Allow public read access (for customers to see shops/menu)
create policy "Public vendors are viewable by everyone" on public.vendors for select using (true);
create policy "Public products are viewable by everyone" on public.products for select using (true);

-- Allow authenticated users (Vendors/Admins) to insert/update
create policy "Enable insert for authenticated users only" on public.vendors for insert with check (auth.role() = 'authenticated');
create policy "Enable update for authenticated users only" on public.vendors for update using (auth.role() = 'authenticated');
