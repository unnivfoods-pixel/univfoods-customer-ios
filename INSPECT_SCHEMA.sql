-- LOGISTICS SCHEMA INSPECTION
-- Run this to see the REAL column names

-- 1. Inspect delivery_riders columns
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'delivery_riders' AND table_schema = 'public';

-- 2. Inspect vendors columns
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'vendors' AND table_schema = 'public';

-- 3. Inspect orders columns
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'orders' AND table_schema = 'public';
-- 4. Inspect registration_requests columns
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'registration_requests' AND table_schema = 'public';
