-- ===========================================
-- PAYMENTS SYSTEM MASTER SCHEMA
-- ===========================================

-- 1. Orders (Enhanced)
-- Note: 'orders' might already exist, so we use ALTER or create if not exists
create table if not exists public.orders (
    id uuid default gen_random_uuid() primary key,
    customer_id uuid references auth.users(id),
    vendor_id uuid references public.vendors(id),
    zone_id uuid references public.delivery_zones(id),
    delivery_partner_id uuid references public.delivery_riders(id),
    
    -- Financials
    order_amount numeric default 0,
    delivery_fee numeric default 0,
    platform_fee numeric default 0,
    tax_amount numeric default 0,
    total_amount numeric default 0,
    
    -- Payment & Status
    payment_method text check (payment_method in ('UPI', 'CARD', 'WALLET', 'COD')),
    payment_status text default 'PENDING', -- INITIATED, SUCCESS, FAILED, REFUNDED
    order_status text default 'PENDING',
    created_at timestamp with time zone default timezone('utc'::text, now())
);

-- 2. Payments (Transaction Log)
create table if not exists public.payments (
    id uuid default gen_random_uuid() primary key,
    order_id uuid references public.orders(id),
    customer_id uuid references auth.users(id),
    payment_method text not null,
    gateway_txn_id text,
    amount numeric not null,
    status text default 'INITIATED', -- INITIATED, SUCCESS, FAILED, REFUNDED
    failure_reason text,
    created_at timestamp with time zone default timezone('utc'::text, now())
);

-- 3. Wallets (User Balance)
create table if not exists public.wallets (
    id uuid default gen_random_uuid() primary key,
    user_id uuid references auth.users(id) unique,
    balance numeric default 0 check (balance >= 0),
    updated_at timestamp with time zone default timezone('utc'::text, now())
);

-- 4. Wallet Transactions (Ledger)
create table if not exists public.wallet_transactions (
    id uuid default gen_random_uuid() primary key,
    wallet_id uuid references public.wallets(id),
    type text check (type in ('CREDIT', 'DEBIT', 'REFUND')),
    amount numeric not null,
    source text, -- ORDER, REFUND, CASHBACK
    reference_id uuid, -- could link to order_id or payment_id
    created_at timestamp with time zone default timezone('utc'::text, now())
);

-- 5. Vendor Settlements
create table if not exists public.vendor_settlements (
    id uuid default gen_random_uuid() primary key,
    vendor_id uuid references public.vendors(id),
    order_id uuid references public.orders(id),
    gross_amount numeric not null,
    commission numeric not null,
    net_amount numeric not null,
    status text default 'PENDING', -- PENDING, PAID
    created_at timestamp with time zone default timezone('utc'::text, now())
);

-- 6. Delivery Payouts
create table if not exists public.delivery_payouts (
    id uuid default gen_random_uuid() primary key,
    delivery_partner_id uuid references public.delivery_riders(id),
    order_id uuid references public.orders(id),
    distance_km numeric default 0,
    base_payout numeric default 0,
    bonus numeric default 0,
    total_payout numeric default 0,
    status text default 'PENDING',
    created_at timestamp with time zone default timezone('utc'::text, now())
);

-- 7. Payment Rules (Admin Control)
create table if not exists public.payment_rules (
    id uuid default gen_random_uuid() primary key,
    scope text check (scope in ('GLOBAL', 'ZONE', 'TIME')),
    zone_id uuid references public.delivery_zones(id) on delete set null,
    payment_method text check (payment_method in ('UPI', 'CARD', 'WALLET', 'COD')),
    min_amount numeric default 0,
    max_amount numeric default 999999,
    enabled boolean default true,
    created_at timestamp with time zone default timezone('utc'::text, now())
);

-- 8. Enable Realtime & RLS
alter publication supabase_realtime add table public.orders, public.payments, public.wallet_transactions, public.vendor_settlements, public.delivery_payouts, public.payment_rules;

alter table public.payments enable row level security;
alter table public.wallets enable row level security;
alter table public.payment_rules enable row level security;

-- Basic Policies (Admin Full Access, User Own Access)
create policy "Admin all payments" on public.payments for all using (true);
create policy "Admin all wallets" on public.wallets for all using (true);
create policy "Admin all rules" on public.payment_rules for all using (true);

-- Seed Initial Global Rules
insert into public.payment_rules (scope, payment_method, enabled) values
('GLOBAL', 'COD', true),
('GLOBAL', 'UPI', true),
('GLOBAL', 'CARD', true),
('GLOBAL', 'WALLET', true);
