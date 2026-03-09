-- 📦 STORAGE BUCKET INITIALIZATION (ROBUST VERSION)
-- Run this in Supabase SQL Editor

-- 1. Create the 'images' bucket if it doesn't exist
INSERT INTO storage.buckets (id, name, public)
VALUES ('images', 'images', true)
ON CONFLICT (id) DO NOTHING;

-- 2. Allow Public Read Access
DROP POLICY IF EXISTS "Public Access" ON storage.objects;
CREATE POLICY "Public Access"
ON storage.objects FOR SELECT
USING ( bucket_id = 'images' );

-- 3. Allow Authenticated Uploads
DROP POLICY IF EXISTS "Authenticated Upload" ON storage.objects;
CREATE POLICY "Authenticated Upload"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'images' AND
  auth.role() = 'authenticated'
);

-- 4. Allow Authenticated Deletion/Update
DROP POLICY IF EXISTS "Authenticated Update" ON storage.objects;
CREATE POLICY "Authenticated Update"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'images' AND
  auth.role() = 'authenticated'
);

DROP POLICY IF EXISTS "Authenticated Delete" ON storage.objects;
CREATE POLICY "Authenticated Delete"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'images' AND
  auth.role() = 'authenticated'
);
