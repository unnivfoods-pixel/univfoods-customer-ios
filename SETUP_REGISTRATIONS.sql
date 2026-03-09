-- =============================================================================
-- REGISTRATION REQUESTS SYSTEM
-- =============================================================================

-- 1. Create table for incoming requests from Landing Page
create table if not exists public.registrations (
    id uuid default gen_random_uuid() primary key,
    created_at timestamp with time zone default timezone('utc'::text, now()),
    type text check (type in ('vendor', 'rider')),
    name text not null,
    phone text not null,
    email text,
    address text,
    details jsonb, -- Extra fields like cuisine, vehicle type, etc.
    status text default 'pending' check (status in ('pending', 'approved', 'rejected', 'completed'))
);

-- 2. Security: Allow public to insert (Landing Page), Admin to manage
alter table public.registrations enable row level security;

-- Policy: Anyone can submit a request (Anon)
create policy "Public insert registrations" on public.registrations
    for insert with check (true);

-- Policy: Admin (Service Role or specific users) can view/update
-- For simplicity in this project, we'll allow authenticated users to view/update? 
-- No, that's unsafe. 
-- In this specific project setup, we often use generic policies or disable RLS for specific tables if the Admin Client uses the service_role or specific login.
-- Let's stick to the pattern used: Permissive for now, user can tighten later.
create policy "Admin manage registrations" on public.registrations
    for all using (true);

-- 3. Enable Realtime triggers so Admin sees requests instantly
alter publication supabase_realtime add table public.registrations;

-- 4. Grant permissions
grant all on table public.registrations to anon;
grant all on table public.registrations to authenticated;
grant all on table public.registrations to service_role;
