DO $$
DECLARE
    r RECORD;
BEGIN
    RAISE NOTICE '--- TABLE: orders ---';
    FOR r IN (SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'orders') LOOP
        RAISE NOTICE 'Column: %, Type: %', r.column_name, r.data_type;
    END LOOP;
    
    RAISE NOTICE '--- POLICIES: orders ---';
    FOR r IN (SELECT policyname, cmd FROM pg_policies WHERE tablename = 'orders') LOOP
        RAISE NOTICE 'Policy: %, Command: %', r.policyname, r.cmd;
    END LOOP;

    RAISE NOTICE '--- TABLE: notifications ---';
    FOR r IN (SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'notifications') LOOP
        RAISE NOTICE 'Column: %, Type: %', r.column_name, r.data_type;
    END LOOP;

    RAISE NOTICE '--- POLICIES: notifications ---';
    FOR r IN (SELECT policyname, cmd FROM pg_policies WHERE tablename = 'notifications') LOOP
        RAISE NOTICE 'Policy: %, Command: %', r.policyname, r.cmd;
    END LOOP;
END $$;
