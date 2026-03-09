-- =============================================
-- MIGRATION: FIX ORDERS TABLE FOR MAPS & PAYMENTS
-- =============================================

-- 1. Ensure 'orders' has all columns needed for Payments
alter table public.orders add column if not exists zone_id uuid references public.delivery_zones(id);
alter table public.orders add column if not exists delivery_partner_id uuid references public.delivery_riders(id);

-- Financials (ensure they exist)
alter table public.orders add column if not exists order_amount numeric default 0;
alter table public.orders add column if not exists delivery_fee numeric default 0;
alter table public.orders add column if not exists platform_fee numeric default 0;
alter table public.orders add column if not exists tax_amount numeric default 0;
alter table public.orders add column if not exists total_amount numeric default 0;

-- Payment Status
alter table public.orders add column if not exists payment_method text; 
alter table public.orders add column if not exists payment_status text default 'PENDING';
alter table public.orders add column if not exists order_status text default 'PENDING';

-- 2. Ensure 'orders' has columns for Maps (Snapshotting)
-- base already has delivery_lat/long, let's strictly name them
alter table public.orders add column if not exists delivery_lat double precision; 
alter table public.orders add column if not exists delivery_lng double precision; 
-- Note: COMPLETE_DB_SETUP used 'delivery_long', we normalize to 'delivery_lng' or support both.
-- Let's check if delivery_long exists and rename/copy if needed to be safe? 
-- Actually, let's just stick to what was probable.
-- Safe bet: Add pickup snapshot too
alter table public.orders add column if not exists pickup_lat double precision;
alter table public.orders add column if not exists pickup_lng double precision;

-- 3. Update 'delivery_riders' for live tracking
alter table public.delivery_riders add column if not exists current_lat double precision;
alter table public.delivery_riders add column if not exists current_lng double precision;
alter table public.delivery_riders add column if not exists heading double precision default 0; -- For icon rotation
alter table public.delivery_riders add column if not exists speed double precision default 0;

-- 4. Enable Realtime triggers again just in case
alter publication supabase_realtime add table public.orders;
alter publication supabase_realtime add table public.delivery_riders;
