-- =========================================================
-- NUCLEAR OPTION: DISABLE RLS (Security) FOR DEMO
-- This allows the app to function fully AUTH-FREE
-- =========================================================

-- 1. Orders Table
alter table public.orders disable row level security;
-- Just in case, grant all to anon
grant all on table public.orders to anon;
grant all on table public.orders to authenticated;
grant all on table public.orders to service_role;

-- 2. Riders Table (For Map/Tracking)
alter table public.delivery_riders disable row level security;
grant all on table public.delivery_riders to anon;

-- 3. Vendors
alter table public.vendors disable row level security;
grant all on table public.vendors to anon;

-- 4. Order Items
alter table public.order_items disable row level security;
grant all on table public.order_items to anon;

-- 5. Addresses
alter table public.addresses disable row level security;
grant all on table public.addresses to anon;

-- 6. Chat/Support (if any)
-- Add any other tables needed here.
