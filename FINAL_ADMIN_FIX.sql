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

-- 4. Enable Realtime
alter publication supabase_realtime add table public.delivery_riders;
alter publication supabase_realtime add table public.app_settings;
alter publication supabase_realtime add table public.customer_profiles;

-- 5. Policies
alter table public.delivery_riders enable row level security;
alter table public.app_settings enable row level security;
alter table public.customer_profiles enable row level security;

-- Allow public read for now (for Admin & Apps) - In prod, lock this down
create policy "Public riders read" on public.delivery_riders for select using (true);
create policy "Public riders insert" on public.delivery_riders for insert with check (true);
create policy "Public riders update" on public.delivery_riders for update using (true);

create policy "Public settings read" on public.app_settings for select using (true);
create policy "Public settings update" on public.app_settings for update using (true);
create policy "Public settings insert" on public.app_settings for insert with check (true);

create policy "Public profiles read" on public.customer_profiles for select using (true);
create policy "Users can update own profile" on public.customer_profiles for update using (auth.uid() = id);
create policy "Users can insert own profile" on public.customer_profiles for insert with check (auth.uid() = id);

-- 6. Trigger to auto-create profile on signup (Best Effort)
create or replace function public.handle_new_user() 
returns trigger as $$
begin
  insert into public.customer_profiles (id, email, full_name, phone)
  values (new.id, new.email, new.raw_user_meta_data->>'full_name', new.phone);
  return new;
end;
$$ language plpgsql security definer;

-- Attempt to create trigger (might fail if no permissions, but worth trying)
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
