-- Ensure the storage bucket exists
INSERT INTO storage.buckets (id, name, public)
VALUES ('images', 'images', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Allow public access to images
CREATE POLICY "Public Access"
ON storage.objects FOR SELECT
USING ( bucket_id = 'images' );

-- Allow authenticated uploads
CREATE POLICY "Authenticated Uploads"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK ( bucket_id = 'images' );

-- Allow authenticated updates
CREATE POLICY "Authenticated Updates"
ON storage.objects FOR UPDATE
TO authenticated
USING ( bucket_id = 'images' );

-- Allow authenticated deletes
CREATE POLICY "Authenticated Deletes"
ON storage.objects FOR DELETE
TO authenticated
USING ( bucket_id = 'images' );
