-- ==========================================================
-- 🛠️ STABILIZATION FIX: PREVENT DATA LOSS & ORPHANING 🛠️
-- ==========================================================

-- 1. FIX: SECURE ORDER OWNERSHIP FALLBACK
-- Prevents disappearing orders when auth.uid() is null (External Auth users)
CREATE OR REPLACE FUNCTION secure_order_ownership()
RETURNS TRIGGER AS $$
BEGIN
    -- 🛡️ Only enforce auth.uid() override if it's available.
    -- If not, but NEW.customer_id is provided, we allow it.
    -- This fixes the bug where guest/firebase orders were being nulled.
    IF auth.uid() IS NOT NULL THEN
        NEW.customer_id := (auth.uid())::text;
    END IF;
    
    -- Safety validation
    IF NEW.customer_id IS NULL THEN
        RAISE EXCEPTION 'customer_id cannot be null for an order';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. FIX: MISSING RLS FOR FAVORITES
-- Day 1 enabled RLS but didn't provide the isolation policy.
DROP POLICY IF EXISTS "IsolationV3_Favorites" ON user_favorites;
CREATE POLICY "IsolationV3_Favorites" ON user_favorites
FOR ALL USING (
    (user_id::text) = (auth.uid()::text) OR 
    (user_id::text) = (current_setting('request.jwt.claims', true)::json->>'sub') OR
    is_admin_strict()
);

-- 3. ENSURE REPLICATION FOR FAVORITES
-- We need realtime sync for favorites to work across devices or after background sync.
DO $$
BEGIN
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE user_favorites;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
END $$;

ALTER TABLE user_favorites REPLICA IDENTITY FULL;

-- 4. CLEANUP ORPHANED ORDERS (Safety Check)
-- Find orders that were set to null by the previous buggy trigger and restore them if possible
-- (Only if it's safe - but we can't easily restore without original IDs. 
--  The previous trigger might have already nulled them on insert).

NOTIFY pgrst, 'reload schema';
