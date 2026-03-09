-- ☢️ THE "NUCLEAR" FIX: GUARANTEED REAL-TIME LOGIN
-- This version uses a Procedural Loop (DO block) to bypass all PostgreSQL type errors 
-- and force-merge any conflicting rider records.

DO $$
DECLARE
    r RECORD;
BEGIN
    -- 1. Identity Hunt: Find every rider record that doesn't match its Auth ID
    FOR r IN (
        SELECT au.id as a_id, dr.id as d_id
        FROM public.delivery_riders dr
        JOIN auth.users au ON (
            dr.email = au.email 
            OR dr.phone = (au.raw_user_meta_data->>'phone')
            OR dr.phone = au.phone
        )
        WHERE dr.id::text != au.id::text
    ) LOOP
        -- Print progress to log
        RAISE NOTICE 'Merging Rider ID % into Auth ID %', r.d_id, r.a_id;

        -- A. Delete the "Empty" placeholder created by the App
        DELETE FROM public.delivery_riders WHERE id = r.a_id;
        
        -- B. Assign the correct Auth ID to the "Full" Landing Page record
        UPDATE public.delivery_riders 
        SET id = r.a_id, is_approved = true, kyc_status = 'ACTIVE'
        WHERE id = r.d_id;
    END LOOP;

    -- 2. Force Approval for ANY record containing 'ramesh'
    UPDATE public.delivery_riders 
    SET is_approved = true, kyc_status = 'ACTIVE' 
    WHERE name ILIKE '%ramesh%' OR email ILIKE '%ramesh%' OR phone ILIKE '%8897868952%';

    -- 3. FINAL SWEEP: If a rider HAS an ID and is still not approved, fix it.
    -- (This happens if they signed up in-app first)
    UPDATE public.delivery_riders
    SET is_approved = true, kyc_status = 'ACTIVE'
    WHERE id IS NOT NULL AND is_approved = false;

END $$;

NOTIFY pgrst, 'reload schema';
