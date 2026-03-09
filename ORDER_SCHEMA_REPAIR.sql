-- 🛠 ORDER SCHEMA REPAIR
-- Purpose: Ensures orders.id is a primary key so foreign keys can reference it.

BEGIN;

-- 1. Check if PK exists, if not, add it.
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_name = 'orders' AND constraint_type = 'PRIMARY KEY'
    ) THEN
        -- Safely try to add primary key. This might fail if duplicate IDs exist.
        ALTER TABLE public.orders ADD PRIMARY KEY (id);
    END IF;
END $$;

-- 2. Ensure its type is UUID (Important for V17 Ledger)
-- If it's TEXT, we convert it.
DO $$ 
BEGIN
    IF (SELECT data_type FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'id') = 'text' THEN
        -- Conversion from text to uuid requires USING cast
        ALTER TABLE public.orders ALTER COLUMN id TYPE UUID USING (id::uuid);
    END IF;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Orders ID is already UUID or cannot be converted. Manual check required if failure continues.';
END $$;

COMMIT;
