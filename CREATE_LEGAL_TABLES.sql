-- =============================================================================
-- FIX ADMIN ISSUE: CREATE MISSING LEGAL TABLES (ROBUST VERSION)
-- =============================================================================

-- 1. Legal Documents Table
CREATE TABLE IF NOT EXISTS public.legal_documents (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    category TEXT NOT NULL, -- 'Privacy Policy', 'Terms of Service', etc.
    target_audience TEXT NOT NULL, -- 'Customers', 'Vendors', 'Delivery'
    title TEXT NOT NULL,
    version TEXT NOT NULL DEFAULT '1.0',
    content TEXT, -- Markdown content
    status TEXT DEFAULT 'draft', -- 'draft', 'published', 'archived'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    published_at TIMESTAMP WITH TIME ZONE
);

-- 2. User Acceptance Logs
CREATE TABLE IF NOT EXISTS public.legal_acceptance (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id),
    document_id UUID REFERENCES public.legal_documents(id),
    accepted_version TEXT NOT NULL,
    accepted_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    ip_address TEXT,
    user_agent TEXT
);

-- 3. Enable Realtime (Safely)
-- We wrap this in a block to ignore the error if it's already added
DO $$
BEGIN
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.legal_documents;
    EXCEPTION WHEN duplicate_object THEN
        NULL; -- Already added, ignore
    END;
    
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.legal_acceptance;
    EXCEPTION WHEN duplicate_object THEN
        NULL; -- Already added, ignore
    END;
END $$;

-- 4. Enable RLS
ALTER TABLE public.legal_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.legal_acceptance ENABLE ROW LEVEL SECURITY;

-- 5. Policies (Drop existing to avoid conflict on re-run)
DROP POLICY IF EXISTS "Admins full access to legal docs" ON public.legal_documents;
CREATE POLICY "Admins full access to legal docs" 
ON public.legal_documents FOR ALL 
USING (true);

DROP POLICY IF EXISTS "Public read published docs" ON public.legal_documents;
CREATE POLICY "Public read published docs" 
ON public.legal_documents FOR SELECT 
USING (status = 'published');

DROP POLICY IF EXISTS "Users can accept docs" ON public.legal_acceptance;
CREATE POLICY "Users can accept docs" 
ON public.legal_acceptance FOR INSERT 
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users view own acceptance" ON public.legal_acceptance;
CREATE POLICY "Users view own acceptance" 
ON public.legal_acceptance FOR SELECT 
USING (auth.uid() = user_id);
