-- =========================================================
-- FINAL SCHEMA FIX: ZONES + PAYMENTS + MAPS (CONSOLIDATED)
-- Run this script ONCE to fix all "Table Not Found" errors.
-- =========================================================

-- 1. Create Delivery Zones (Full Spec)
create table if not exists public.delivery_zones (
  id uuid default gen_random_uuid() primary key,
  created_at timestamp with time zone default timezone('utc'::text, now()),
  
  -- Basic Info
  name text not null,
  type text default 'allowed', -- 'allowed', 'surge', 'blocked'
  description text,
  city text,
  priority integer default 0,
  
  -- Geometry
  coordinates jsonb not null, -- Array of points [{lat, lng}, ...]

  -- Pricing Logic
  base_delivery_fee numeric default 40,
  per_km_charge numeric default 5,
  surge_multiplier numeric default 1.0,
  min_order_free_delivery numeric default 500,
  free_delivery_radius numeric default 0,
  
  -- Operational Rules
  max_delivery_radius numeric default 15,
  min_riders_required integer default 0,
  active_days jsonb default '["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]'::jsonb,
  open_time time default '06:00:00',
  close_time time default '23:59:00',
  
  -- Flags
  is_active boolean default true,
  feature_flags jsonb default '{"cod_allowed": true, "rain_mode": false}'::jsonb,
  excluded_vendors uuid[] default '{}'::uuid[]
);

-- 2. Audit Logs for Zones
create table if not exists public.zone_audit_logs (
    id uuid default gen_random_uuid() primary key,
    zone_id uuid references public.delivery_zones(id) on delete set null,
    action text, 
    changed_by uuid references auth.users(id),
    old_data jsonb,
    new_data jsonb,
    created_at timestamp with time zone default timezone('utc'::text, now())
);

-- 3. Payments Ecosystem
create table if not exists public.payments (
    id uuid default gen_random_uuid() primary key,
    order_id uuid, -- link later
    customer_id uuid references auth.users(id),
    payment_method text check (payment_method in ('UPI', 'CARD', 'WALLET', 'COD')),
    gateway_txn_id text,
    amount numeric not null,
    status text default 'INITIATED', 
    failure_reason text,
    created_at timestamp with time zone default timezone('utc'::text, now())
);

create table if not exists public.wallets (
    id uuid default gen_random_uuid() primary key,
    user_id uuid references auth.users(id) unique,
    balance numeric default 0 check (balance >= 0),
    updated_at timestamp with time zone default timezone('utc'::text, now())
);

create table if not exists public.vendor_settlements (
    id uuid default gen_random_uuid() primary key,
    vendor_id uuid references public.vendors(id),
    order_id uuid, -- link later
    gross_amount numeric not null,
    commission numeric not null,
    net_amount numeric not null,
    status text default 'PENDING',
    created_at timestamp with time zone default timezone('utc'::text, now())
);

create table if not exists public.payment_rules (
    id uuid default gen_random_uuid() primary key,
    scope text check (scope in ('GLOBAL', 'ZONE', 'TIME')),
    zone_id uuid references public.delivery_zones(id) on delete set null,
    payment_method text,
    enabled boolean default true,
    min_amount numeric default 0,
    created_at timestamp with time zone default timezone('utc'::text, now())
);

-- 4. Patch ORDERS Table (Foreign Keys + Map Support)
-- Note: 'orders' table presumably exists from initial setup. We modify it safeley.
do $$ 
begin
    -- Add proper foreign keys if they don't exist
    if not exists (select 1 from information_schema.columns where table_name='orders' and column_name='zone_id') then
        alter table public.orders add column zone_id uuid references public.delivery_zones(id);
    end if;

    if not exists (select 1 from information_schema.columns where table_name='orders' and column_name='delivery_partner_id') then
        alter table public.orders add column delivery_partner_id uuid references public.delivery_riders(id);
    end if;

    -- Financials
    alter table public.orders add column if not exists payment_method text;
    alter table public.orders add column if not exists payment_status text default 'PENDING';
    alter table public.orders add column if not exists total_amount numeric default 0;

    -- Maps (Snapshots)
    alter table public.orders add column if not exists pickup_lat double precision;
    alter table public.orders add column if not exists pickup_lng double precision;
    alter table public.orders add column if not exists delivery_lat double precision;
    alter table public.orders add column if not exists delivery_lng double precision;
end $$;

-- 5. Patch RIDERS Table (Live Connect)
alter table public.delivery_riders add column if not exists current_lat double precision;
alter table public.delivery_riders add column if not exists current_lng double precision;
alter table public.delivery_riders add column if not exists heading double precision default 0;
alter table public.delivery_riders add column if not exists speed double precision default 0;

-- 6. Enable Realtime
alter publication supabase_realtime add table public.delivery_zones;
alter publication supabase_realtime add table public.payments;
alter publication supabase_realtime add table public.payment_rules;
alter publication supabase_realtime add table public.wallets;
alter publication supabase_realtime add table public.vendor_settlements;

-- 7. Security Policies (Open Admin Access for simplicity in dev)
alter table public.delivery_zones enable row level security;
create policy "Admin all zones" on public.delivery_zones for all using (true);

alter table public.payments enable row level security;
create policy "Admin all payments" on public.payments for all using (true);
