-- ===================================================
-- 📍 FIX user_addresses SCHEMA DISCREPANCIES
-- ===================================================

-- 1. Ensure 'label' column exists (some versions used 'title')
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_addresses' AND column_name='title') THEN
        ALTER TABLE public.user_addresses RENAME COLUMN title TO label;
    ELSIF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_addresses' AND column_name='label') THEN
        ALTER TABLE public.user_addresses ADD COLUMN label TEXT DEFAULT 'Home';
    END IF;
END $$;

-- 2. Add phone and pincode columns
ALTER TABLE public.user_addresses
  ADD COLUMN IF NOT EXISTS phone TEXT,
  ADD COLUMN IF NOT EXISTS pincode TEXT;

-- 3. Ensure user_id is TEXT (to match SupabaseConfig.forcedUserId)
ALTER TABLE public.user_addresses ALTER COLUMN user_id TYPE TEXT;

-- 4. Refresh PostgREST cache
NOTIFY pgrst, 'reload schema';

-- Verify
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'user_addresses'
  AND table_schema = 'public'
ORDER BY ordinal_position;
