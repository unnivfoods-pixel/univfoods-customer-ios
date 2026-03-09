-- Ensure legal_documents table has correct schema
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='legal_documents' AND column_name='target_audience') THEN
        ALTER TABLE legal_documents ADD COLUMN target_audience TEXT DEFAULT 'ALL';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='legal_documents' AND column_name='category') THEN
        ALTER TABLE legal_documents ADD COLUMN category TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='legal_documents' AND column_name='status') THEN
        ALTER TABLE legal_documents ADD COLUMN status TEXT DEFAULT 'draft';
    END IF;
END $$;

-- Ensure delivery_riders table has location columns
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='delivery_riders' AND column_name='latitude') THEN
        ALTER TABLE delivery_riders ADD COLUMN latitude DOUBLE PRECISION;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='delivery_riders' AND column_name='longitude') THEN
        ALTER TABLE delivery_riders ADD COLUMN longitude DOUBLE PRECISION;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='delivery_riders' AND column_name='heading') THEN
        ALTER TABLE delivery_riders ADD COLUMN heading DOUBLE PRECISION;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='delivery_riders' AND column_name='speed') THEN
        ALTER TABLE delivery_riders ADD COLUMN speed DOUBLE PRECISION;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='delivery_riders' AND column_name='last_updated') THEN
        ALTER TABLE delivery_riders ADD COLUMN last_updated TIMESTAMPTZ DEFAULT NOW();
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='delivery_riders' AND column_name='is_online') THEN
        ALTER TABLE delivery_riders ADD COLUMN is_online BOOLEAN DEFAULT FALSE;
    END IF;
END $$;

-- Enable Realtime (Safer version)
DO $$
BEGIN
    -- Add legal_documents if not already present
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'legal_documents'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE legal_documents;
    END IF;

    -- Add delivery_riders if not already present
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'delivery_riders'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE delivery_riders;
    END IF;

    -- Add orders if not already present
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'orders'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE orders;
    END IF;
END $$;

-- DATA MIGRATION: Fix old legal policies to show up in the new system
-- This sets defaults for records that were created 'the old way'
UPDATE legal_documents 
SET target_audience = 'ALL' 
WHERE target_audience IS NULL;

UPDATE legal_documents 
SET status = 'published' 
WHERE status IS NULL;

UPDATE legal_documents 
SET category = 'PRIVACY_POLICY' 
WHERE category IS NULL AND title ILIKE '%privacy%';

UPDATE legal_documents 
SET category = 'TERMS_CONDITIONS' 
WHERE category IS NULL AND title ILIKE '%terms%';
