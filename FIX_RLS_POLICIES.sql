-- ==========================================
-- FIX RLS POLICIES FOR ADMIN & CUSTOMER ACCESS
-- Run this in the Supabase SQL Editor to fix "Add Item" & "Not Connected" issues.
-- ==========================================

-- 1. Fix PRODUCTS Table Policies (Allow Admin/Vendor to Add Items)
drop policy if exists "Public products read" on public.products;
drop policy if exists "Enable all access for products" on public.products;

-- Allow everyone to read (needed for Customer App)
create policy "Public products read" on public.products for select using (true);

-- Allow everyone to insert/update/delete (Simplified for Admin Panel usage without strict auth)
create policy "Enable all access for products" on public.products for all using (true) with check (true);


-- 2. Fix VENDORS Table Policies
drop policy if exists "Public read" on public.vendors;
drop policy if exists "Authenticated insert" on public.vendors;
drop policy if exists "Authenticated update" on public.vendors;
drop policy if exists "Enable all access for vendors" on public.vendors;

create policy "Enable all access for vendors" on public.vendors for all using (true) with check (true);


-- 3. Fix ORDERS Table Policies
drop policy if exists "Public orders insert" on public.orders;
drop policy if exists "Public orders select" on public.orders;
drop policy if exists "Enable all access for orders" on public.orders;

create policy "Enable all access for orders" on public.orders for all using (true) with check (true);


-- 4. Fix NEW TABLES (Promotions/Banners) just in case
alter table public.banners enable row level security;
drop policy if exists "Enable all access for admins" on public.banners;
drop policy if exists "Enable read access for all users" on public.banners;

create policy "Enable all access for banners" on public.banners for all using (true) with check (true);


-- 5. Fix CATEGORIES Table (if using dynamic categories)
create table if not exists public.categories (
    id uuid default gen_random_uuid() primary key,
    created_at timestamp with time zone default timezone('utc'::text, now()),
    name text not null,
    image_url text,
    priority integer default 0,
    is_active boolean default true
);

alter publication supabase_realtime add table public.categories;
alter table public.categories enable row level security;
create policy "Enable all access for categories" on public.categories for all using (true) with check (true);

-- 6. Ensure Realtime is enabled for core tables (Double Check)
alter publication supabase_realtime add table public.vendors;
alter publication supabase_realtime add table public.products;
alter publication supabase_realtime add table public.orders;
alter publication supabase_realtime add table public.banners;

