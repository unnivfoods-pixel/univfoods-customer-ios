-- ===========================================
-- DELIVERY ZONES - MEGA UPDATE
-- ===========================================

-- 1. Extend Delivery Zones Table with ALL Feature Fields
alter table public.delivery_zones 
add column if not exists description text,
add column if not exists priority integer default 0,
add column if not exists city text,

-- Pricing Rules
add column if not exists base_delivery_fee numeric default 40,
add column if not exists per_km_charge numeric default 5,
add column if not exists free_delivery_radius numeric default 0,
add column if not exists min_order_free_delivery numeric default 500,
add column if not exists surge_multiplier numeric default 1.0,

-- Operational Rules
add column if not exists max_delivery_radius numeric default 15,
add column if not exists min_riders_required integer default 0,
add column if not exists active_days jsonb default '["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]'::jsonb,
add column if not exists open_time time default '06:00:00',
add column if not exists close_time time default '23:59:00',

-- Feature Flags & Permissions (JSONB is best for scalable flags)
add column if not exists feature_flags jsonb default '{"cod_allowed": true, "express_delivery": false, "rain_mode": false}'::jsonb,
add column if not exists excluded_vendors uuid[] default '{}'::uuid[]; -- Array of Vendor IDs blocklisted in this zone

-- 2. Audit Log Table (Simple Version)
create table if not exists public.zone_audit_logs (
    id uuid default gen_random_uuid() primary key,
    zone_id uuid references public.delivery_zones(id) on delete set null,
    action text, -- 'created', 'updated', 'deleted'
    changed_by uuid references auth.users(id),
    old_data jsonb,
    new_data jsonb,
    created_at timestamp with time zone default timezone('utc'::text, now())
);

-- 3. Enable RLS for Audit
alter table public.zone_audit_logs enable row level security;
create policy "Admin read audit" on public.zone_audit_logs for select using (true);
create policy "Systems create audit" on public.zone_audit_logs for insert with check (true);
