-- =========================================================================
-- STORAGE BUCKET SETUP
-- Run this in Supabase SQL Editor to enable Image Uploads
-- =========================================================================

-- 1. Create a storage bucket called 'images'
insert into storage.buckets (id, name, public)
values ('images', 'images', true)
on conflict (id) do nothing;

-- 2. Security Policies (Allow fully public access for this MVP)
-- Allow public access to view images
create policy "Public Access"
on storage.objects for select
using ( bucket_id = 'images' );

-- Allow authenticated users (Admin) to upload images
create policy "Authenticated Upload"
on storage.objects for insert
with check ( bucket_id = 'images' and auth.role() = 'authenticated' );

-- Allow authenticated users to update images
create policy "Authenticated Update"
on storage.objects for update
using ( bucket_id = 'images' and auth.role() = 'authenticated' );

-- Allow authenticated users to delete images
create policy "Authenticated Delete"
on storage.objects for delete
using ( bucket_id = 'images' and auth.role() = 'authenticated' );

-- Note: In a stricter production app, you might restrict uploads to admin only.
-- Since this is an admin panel running with an anon key but likely behind login?
-- Wait, the admin panel uses email/pass login, so auth.role() = 'authenticated' works.
