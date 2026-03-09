-- Add Email column to Vendors for manual linking
alter table public.vendors add column if not exists email text;
-- Ensure uniqueness if we want 1:1, but maybe not strict constraint yet to avoid breaking current data
-- create unique index if not exists idx_vendors_email on public.vendors(email);

-- Update the Trigger to Auto-Link Vendors on Signup
create or replace function public.handle_new_user() 
returns trigger as $$
begin
  -- 1. Create Customer Profile (Standard)
  insert into public.customer_profiles (id, email, full_name, phone)
  values (new.id, new.email, new.raw_user_meta_data->>'full_name', new.phone);
  
  -- 2. Auto-Link Vendor if email matches
  -- This allows Admin to pre-create a Vendor (Curry Point) with an email
  -- When the user signs up with that email, they become the owner.
  if new.email is not null then
      update public.vendors 
      set owner_id = new.id 
      where email = new.email 
      and (owner_id is null or owner_id = new.id); -- Claim ownership
  end if;

  return new;
end;
$$ language plpgsql security definer;
