-- 🛰️ EMERGENCY REALTIME ANCHOR & DATA RECOVERY (V11)
-- Resolves: "Nothing syncs" and "Missing vendor identity" issues.

BEGIN;

-- 1. DATA RECOVERY: Link orphaned Vendors to Auth Accounts
-- This fixes the case where vendors were approved but owner_id was missing.
UPDATE public.vendors v
SET owner_id = u.id
FROM auth.users u
WHERE (v.email = u.email OR v.phone = u.phone)
AND v.owner_id IS NULL;

-- 2. DEDUPLICATION: Remove rogue duplicate vendor records
-- Keeps only the most recent vendor record per owner to prevent .single() errors.
DELETE FROM public.vendors
WHERE id IN (
    SELECT id FROM (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY owner_id ORDER BY created_at DESC) as rnk
        FROM public.vendors
        WHERE owner_id IS NOT NULL
    ) t WHERE t.rnk > 1
);

-- 3. SCHEMA ANCHORING: Enforce Unique Identity
-- This prevents future "nothing syncs" errors by ensuring 1 User = 1 Boutique.
ALTER TABLE public.vendors DROP CONSTRAINT IF EXISTS unique_vendor_owner;
DELETE FROM public.vendors WHERE owner_id IS NULL; -- Clean up unlinked records
ALTER TABLE public.vendors ADD CONSTRAINT unique_vendor_owner UNIQUE (owner_id);

-- 4. REALTIME GEYSER: Force Broadcast
-- Re-initializing the publication for all mission-critical tables.
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

-- 5. REPLICA IDENTITY (The Real-time Secret)
-- Without FULL, Postgres doesn't send the "Old" data, which breaks complex filters.
ALTER TABLE public.vendors REPLICA IDENTITY FULL;
ALTER TABLE public.products REPLICA IDENTITY FULL;
ALTER TABLE public.orders REPLICA IDENTITY FULL;
ALTER TABLE public.delivery_riders REPLICA IDENTITY FULL;

-- 6. STATUS NORMALIZATION
UPDATE public.vendors SET status = 'ONLINE' WHERE status IS NULL OR status = 'Active' OR status = 'active';

COMMIT;

-- Force a schema reload for the PostgREST cache
NOTIFY pgrst, 'reload schema';
