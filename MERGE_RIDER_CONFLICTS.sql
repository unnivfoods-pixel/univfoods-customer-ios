-- 🛠️ FINAL TYPE-SAFE MERGE REPAIR
-- Resolves "operator does not exist: text = uuid" in DELETE/UPDATE statements

BEGIN;

-- 1. Create a mapping with explicit UUID types
CREATE TEMP TABLE rider_repair AS
SELECT 
    au.id as auth_id, 
    dr.id as old_rider_id
FROM public.delivery_riders dr
JOIN auth.users au ON (dr.email = au.email OR dr.phone = (au.raw_user_meta_data->>'phone'))
WHERE dr.id::text != au.id::text;

-- 2. Remove the "empty" app-created record (caseting for safety)
DELETE FROM public.delivery_riders 
WHERE id::text IN (SELECT auth_id::text FROM rider_repair);

-- 3. Update the "real" landing-page record with the correct Auth ID
UPDATE public.delivery_riders dr
SET 
    id = rr.auth_id,
    is_approved = true,
    kyc_status = 'ACTIVE'
FROM rider_repair rr
WHERE dr.id::text = rr.old_rider_id::text;

-- 4. Final rescue for Ramesh
UPDATE public.delivery_riders 
SET is_approved = true, kyc_status = 'ACTIVE' 
WHERE name ILIKE '%ramesh%' OR email ILIKE '%ramesh%';

DROP TABLE IF EXISTS rider_repair;

COMMIT;

NOTIFY pgrst, 'reload schema';
