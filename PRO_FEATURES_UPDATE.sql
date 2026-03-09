-- =========================================================================
-- PRO FEATURES UPDATE (Admin Control & Financials)
-- Run this in Supabase SQL Editor to upgrade the platform.
-- =========================================================================

-- 1. UPGRADE VENDORS TABLE (Financials & Control)
ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS commission_rate numeric default 15.0,
ADD COLUMN IF NOT EXISTS payout_cycle text default 'Weekly',
ADD COLUMN IF NOT EXISTS is_verified boolean default false,
ADD COLUMN IF NOT EXISTS wallet_balance numeric default 0.0,
ADD COLUMN IF NOT EXISTS min_order_value numeric default 0.0;

-- 2. CREATE DELIVERY RIDERS TABLE (Missing Core Component)
create table if not exists public.delivery_riders (
  id uuid default gen_random_uuid() primary key,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  user_id uuid references auth.users(id), -- Link to Auth User
  name text not null,
  phone text,
  city text
);

-- Upgrade fields if table already exists (or was just created with basic fields)
ALTER TABLE public.delivery_riders 
ADD COLUMN IF NOT EXISTS city text,
ADD COLUMN IF NOT EXISTS phone text,
ADD COLUMN IF NOT EXISTS name text,
ADD COLUMN IF NOT EXISTS vehicle_type text default 'Bike',
ADD COLUMN IF NOT EXISTS vehicle_number text,
ADD COLUMN IF NOT EXISTS status text default 'Pending', -- Pending, Approved, Suspended
ADD COLUMN IF NOT EXISTS is_online boolean default false,
ADD COLUMN IF NOT EXISTS current_lat double precision,
ADD COLUMN IF NOT EXISTS current_lng double precision,
ADD COLUMN IF NOT EXISTS wallet_balance numeric default 0.0,
ADD COLUMN IF NOT EXISTS rating numeric default 5.0,
ADD COLUMN IF NOT EXISTS total_deliveries integer default 0;


-- 3. ENABLE REALTIME FOR RIDERS (For Live Tracking)
do $$
begin
  alter publication supabase_realtime add table public.delivery_riders;
exception when others then null;
end $$;

-- 4. RLS POLICIES FOR RIDERS
alter table public.delivery_riders enable row level security;

do $$
begin
  create policy "Public read riders" on public.delivery_riders for select using (true);
exception when others then null;
end $$;

do $$
begin
  create policy "Riders update own location" on public.delivery_riders for update using (auth.uid() = user_id);
exception when others then null;
end $$;

-- 5. UPGRADE ORDERS TABLE (For Assignment & Payouts)
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS delivery_partner_id uuid references public.delivery_riders(id),
ADD COLUMN IF NOT EXISTS delivery_fee numeric default 0.0,
ADD COLUMN IF NOT EXISTS platform_fee numeric default 0.0,
ADD COLUMN IF NOT EXISTS taxes numeric default 0.0,
ADD COLUMN IF NOT EXISTS payment_method text default 'COD', -- COD, UPI, Card
ADD COLUMN IF NOT EXISTS payment_status text default 'Pending'; -- Pending, Paid, Refunded

-- 6. SEED SOME DUMMY RIDERS (For Admin Map Demo)
-- Check if mock data exists before inserting to avoid duplicates usually not needed for seed scripts but good for idempotency 
-- ignoring check for simplicity as UUIDs are auto-generated
INSERT INTO public.delivery_riders (name, phone, status, is_online, current_lat, current_lng, city, vehicle_type)
VALUES 
('Raju Kumar', '+919999999991', 'Approved', true, 17.3850, 78.4867, 'Hyderabad', 'Bike'),
('Suresh Reddy', '+919999999992', 'Approved', true, 17.3950, 78.4967, 'Hyderabad', 'Bike'),
('Ahmed Khan', '+919999999993', 'Approved', false, 17.3750, 78.4767, 'Hyderabad', 'Electric Scooter');
