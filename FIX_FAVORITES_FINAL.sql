-- 🔧 FIX FAVORITES SYSTEM: Sync Naming & RLS
-- This script ensures user_favorites is the source of truth and has proper RLS policies.

-- 1. Ensure user_favorites table is correct
CREATE TABLE IF NOT EXISTS public.user_favorites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    user_id UUID NOT NULL,
    vendor_id UUID REFERENCES public.vendors(id) ON DELETE CASCADE,
    product_id UUID REFERENCES public.products(id) ON DELETE CASCADE
);

-- 2. Add product_id if not present (defensive)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_favorites' AND column_name = 'product_id') THEN
        ALTER TABLE public.user_favorites ADD COLUMN product_id UUID REFERENCES public.products(id) ON DELETE CASCADE;
    END IF;
END $$;

-- 3. Fix Unique Constraints (Postgres allows multiple NULLs in unique constraints by default)
-- We want: Only ONE favorite per user-vendor (for vendor favs) AND Only ONE favorite per user-product
ALTER TABLE public.user_favorites DROP CONSTRAINT IF EXISTS unique_user_vendor_fav;
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_vendor_fav ON public.user_favorites (user_id, vendor_id) WHERE (product_id IS NULL);

ALTER TABLE public.user_favorites DROP CONSTRAINT IF EXISTS unique_user_product_fav;
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_product_fav ON public.user_favorites (user_id, product_id) WHERE (product_id IS NOT NULL);

-- 4. Enable RLS and Realtime
ALTER TABLE public.user_favorites ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'user_favorites') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.user_favorites;
    END IF;
END $$;

-- 5. Define RLS Policies for user_favorites
-- (These were missing because they were incorrectly applied to a table named 'favorites')
DROP POLICY IF EXISTS "Users see their own favorites" ON public.user_favorites;
CREATE POLICY "Users see their own favorites" ON public.user_favorites
    FOR SELECT
    USING (
        user_id = auth.uid() 
        OR user_id = (current_setting('app.current_user_id', true))::uuid
    );

DROP POLICY IF EXISTS "Users manage their own favorites" ON public.user_favorites;
CREATE POLICY "Users manage their own favorites" ON public.user_favorites
    FOR ALL
    USING (
        user_id = auth.uid() 
        OR user_id = (current_setting('app.current_user_id', true))::uuid
    )
    WITH CHECK (
        user_id = auth.uid() 
        OR user_id = (current_setting('app.current_user_id', true))::uuid
    );

-- 6. Cleanup naming confusion (Optional but recommended)
-- If a table specifically named 'favorites' exists and is empty, we can drop it to avoid future confusion.
-- DROP TABLE IF EXISTS public.favorites;

-- ✅ DONE! Favorites will now persist and sync between Menu and Profile.
