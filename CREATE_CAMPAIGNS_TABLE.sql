-- Create the campaigns table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.campaigns (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    image_url TEXT,
    target_audience TEXT DEFAULT 'ALL',
    status TEXT DEFAULT 'draft',
    created_by UUID REFERENCES auth.users(id)
);

-- Enable Realtime for campaigns
ALTER PUBLICATION supabase_realtime ADD TABLE campaigns;

-- Policy (Optional but good practice): Allow authenticated users to read/insert
UPDATE pg_settings SET setting = 'session_replication_role' WHERE name = 'replica' AND setting = 'origin';
ALTER TABLE public.campaigns ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable read/write for authenticated users only"
ON public.campaigns
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);
