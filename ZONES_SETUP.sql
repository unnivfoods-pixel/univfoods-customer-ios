-- 1. Create Delivery Zones Table
create table if not exists public.delivery_zones (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  type text default 'sales', -- options: 'allowed', 'surge', 'blocked'
  coordinates jsonb not null, -- Array of points [{lat, lng}, ...]
  delivery_fee numeric default 0, -- Extra fee for this zone
  is_active boolean default true,
  created_at timestamp with time zone default timezone('utc'::text, now())
);

-- 2. Update Vendors with Radius Controls
alter table public.vendors add column if not exists max_radius_km numeric default 10;
alter table public.vendors add column if not exists is_radius_locked boolean default false;
alter table public.vendors add column if not exists delivery_fee_base numeric default 10;
alter table public.vendors add column if not exists delivery_fee_per_km numeric default 2;

-- 3. Enable Realtime for Zones
alter publication supabase_realtime add table public.delivery_zones;

-- 4. Policies for Zones
alter table public.delivery_zones enable row level security;
create policy "Public zones read" on public.delivery_zones for select using (true);
create policy "Public zones all" on public.delivery_zones for all using (true); -- Admin full access (simplified)

-- 5. Seed some initial Zones (Mock Geo Example - Hyderabad)
insert into public.delivery_zones (name, type, coordinates, delivery_fee)
values 
(
  'Core City Zone', 
  'allowed', 
  '[
    {"lat": 17.3850, "lng": 78.4867},
    {"lat": 17.4000, "lng": 78.4900},
    {"lat": 17.3900, "lng": 78.5000},
    {"lat": 17.3700, "lng": 78.4800}
  ]'::jsonb,
  20
);
