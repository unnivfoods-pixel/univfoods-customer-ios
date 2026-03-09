-- =============================================================================
-- FINAL CONNECT SETUP: AUTOMATIC LOGINS & ACCOUNT LINKING
-- =============================================================================

-- 1. Ensure Delivery Riders can log in
ALTER TABLE "delivery_riders" ADD COLUMN IF NOT EXISTS "user_id" uuid REFERENCES auth.users(id);

-- 2. Trigger Function to Link Profile by Phone Number on Signup
create or replace function public.link_profile_by_phone()
returns trigger as $$
declare
    clean_phone text;
begin
    -- Basic cleaning (ensure +91 format if locally stored that way, or just match)
    -- Ideally, perform strict matching.
    
    -- 1. Try to link Vendor
    update public.vendors 
    set owner_id = new.id 
    where phone = new.phone 
    and (owner_id is null or owner_id = new.id); -- Claim the profile
    
    -- 2. Try to link Rider
    update public.delivery_riders 
    set user_id = new.id 
    where phone = new.phone 
    and (user_id is null or user_id = new.id); -- Claim the profile

    return new;
end;
$$ language plpgsql security definer;

-- 3. Attach Trigger to Auth.Users
drop trigger if exists on_auth_user_created_link_profile on auth.users;
create trigger on_auth_user_created_link_profile
    after insert on auth.users
    for each row execute procedure public.link_profile_by_phone();

-- 4. Run the Registration Setup (Included here for convenience if running one file)
-- (Code from SETUP_REGISTRATIONS.sql)
create table if not exists public.registrations (
    id uuid default gen_random_uuid() primary key,
    created_at timestamp with time zone default timezone('utc'::text, now()),
    type text check (type in ('vendor', 'rider')),
    name text not null,
    phone text not null,
    email text,
    address text,
    details jsonb, 
    status text default 'pending'
);
alter table public.registrations enable row level security;
drop policy if exists "Public insert registrations" on public.registrations;
create policy "Public insert registrations" on public.registrations for insert with check (true);
drop policy if exists "Admin manage registrations" on public.registrations;
create policy "Admin manage registrations" on public.registrations for all using (true);
grant all on table public.registrations to anon, authenticated, service_role;
alter publication supabase_realtime add table public.registrations;
