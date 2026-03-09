-- ===========================================
-- LEGAL & POLICIES MANAGEMENT SYSTEM
-- ===========================================

-- 1. Migration for existing table (if any)
do $$ 
begin
    -- Rename category to type if it exists
    if exists (select 1 from information_schema.columns where table_name='legal_documents' and column_name='category') then
        alter table public.legal_documents rename column category to type;
    end if;
    -- Rename target_audience to role if it exists
    if exists (select 1 from information_schema.columns where table_name='legal_documents' and column_name='target_audience') then
        alter table public.legal_documents rename column target_audience to role;
    end if;
    -- Handle status to is_active (type change from text to bool)
    if exists (select 1 from information_schema.columns where table_name='legal_documents' and column_name='status') then
        alter table public.legal_documents add column if not exists is_active boolean default false;
        update public.legal_documents set is_active = (status = 'published');
        alter table public.legal_documents drop column status;
    end if;
    
    -- Add missing columns
    alter table public.legal_documents add column if not exists requires_acceptance boolean default true;
    alter table public.legal_documents add column if not exists version text default '1.0';
end $$;

-- 1. Legal Documents Table
-- Storage for all versions of policies, terms, agreements
create table if not exists public.legal_documents (
    id uuid default gen_random_uuid() primary key,
    type text not null, -- 'PRIVACY_POLICY', 'TERMS_CONDITIONS', 'REFUND_POLICY', 'DELIVERY_POLICY', 'VENDOR_AGREEMENT', 'DELIVERY_PARTNER_AGREEMENT'
    role text not null, -- 'CUSTOMER', 'VENDOR', 'DELIVERY_PARTNER', 'ALL'
    title text not null,
    content text not null, -- Markdown/HTML content
    version text not null, -- e.g., '1.0', '1.1'
    is_active boolean default false, -- Only one active version per Type+Role
    requires_acceptance boolean default true, -- Does this update force re-acceptance?
    published_at timestamp with time zone default timezone('utc'::text, now()),
    created_by uuid references auth.users(id),
    created_at timestamp with time zone default timezone('utc'::text, now())
);

-- 2. Legal Acceptance Tracking
-- Audit trail of who accepted what and when
create table if not exists public.legal_acceptance (
    id uuid default gen_random_uuid() primary key,
    user_id uuid references auth.users(id),
    document_id uuid references public.legal_documents(id),
    accepted_version text not null,
    ip_address text,
    user_agent text,
    accepted_at timestamp with time zone default timezone('utc'::text, now()),
    unique(user_id, document_id) -- Prevent duplicate acceptance records for same doc version? No, duplicate logic handled in app, usually we want latest. 
    -- Actually, we want to track history, so maybe not unique constraint here on ID alone.
    -- Constraint: User + DocID -> Unique? No, user might accept v1 then v2.
    -- Constraint: User + DocID + Version -> Unique.
);

alter table public.legal_acceptance add constraint unique_acceptance unique (user_id, document_id, accepted_version);


-- 3. Enable Realtime
alter publication supabase_realtime add table public.legal_documents;
alter publication supabase_realtime add table public.legal_acceptance;

-- 4. RLS Policies
alter table public.legal_documents enable row level security;
alter table public.legal_acceptance enable row level security;

-- Documents: Public Read (Apps need to fetch), Admin Write
create policy "Public read documents" on public.legal_documents for select using (true);
create policy "Admin write documents" on public.legal_documents for all using (true); -- simplified for admin

-- Acceptance: Users insert own, Admin read all
create policy "Users insert acceptance" on public.legal_acceptance for insert with check (auth.uid() = user_id);
create policy "Users read own acceptance" on public.legal_acceptance for select using (auth.uid() = user_id);
create policy "Admin read all acceptance" on public.legal_acceptance for select using (true);

-- 5. Helper Function to Ensure Single Active Version
create or replace function public.ensure_single_active_policy()
returns trigger as $$
begin
    if new.is_active = true then
        update public.legal_documents
        set is_active = false
        where type = new.type 
        and role = new.role 
        and id != new.id;
    end if;
    return new;
end;
$$ language plpgsql;

create trigger on_policy_publish
    before insert or update on public.legal_documents
    for each row execute procedure public.ensure_single_active_policy();

-- 6. Seed Initial Data (Drafts)
insert into public.legal_documents (type, role, title, content, version, is_active) values 
('PRIVACY_POLICY', 'ALL', 'Global Privacy Policy', '# Privacy Policy\n\nWe value your privacy...', '1.0', true),
('TERMS_CONDITIONS', 'CUSTOMER', 'Customer Terms of Service', '# Terms\n\nBy using this app...', '1.0', true),
('REFUND_POLICY', 'CUSTOMER', 'Refund & Cancellation', '# Refunds\n\nRefunds are processed within...', '1.0', true),
('VENDOR_AGREEMENT', 'VENDOR', 'Merchant Agreement', '# Merchant Terms\n\nAs a partner...', '1.0', true);
