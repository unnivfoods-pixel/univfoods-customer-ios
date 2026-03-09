-- Create the registrations table
create table if not exists public.registrations (
  id uuid default gen_random_uuid() primary key,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  type text not null, -- 'vendor' or 'rider'
  name text not null,
  phone text,
  email text not null,
  address text,
  status text default 'pending'::text,
  details jsonb, -- Stores flexible data like cuisine, vehicle_type, and user_id info
  user_id uuid references auth.users(id) -- Linked auth user
);

-- Enable Row Level Security (RLS)
alter table public.registrations enable row level security;

-- Create policies to allow public insert (for the landing page)
create policy "Allow public to insert registrations"
on public.registrations for insert
to anon, authenticated
with check (true);

-- Create policies to allow admins (or everyone for now in dev) to view/update
create policy "Allow public to view registrations"
on public.registrations for select
to anon, authenticated
using (true);

create policy "Allow public to update registrations"
on public.registrations for update
to anon, authenticated
using (true);

-- Grant permissions to anon and authenticated roles
grant all on public.registrations to anon;
grant all on public.registrations to authenticated;
grant all on public.registrations to service_role;

-- Also ensure delivery_riders exists (just in case)
create table if not exists public.delivery_riders (
    id uuid default gen_random_uuid() primary key,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    name text,
    phone text,
    status text default 'Offline',
    vehicle_type text,
    current_location geography(Point),
    user_id uuid references auth.users(id)
);

-- Enable RLS for delivery_riders
alter table public.delivery_riders enable row level security;

-- Grant permissions for delivery_riders
grant all on public.delivery_riders to anon;
grant all on public.delivery_riders to authenticated;
grant all on public.delivery_riders to service_role;

-- Simple policy for delivery_riders
create policy "Enable all access for delivery_riders"
on public.delivery_riders for all
using (true)
with check (true);
