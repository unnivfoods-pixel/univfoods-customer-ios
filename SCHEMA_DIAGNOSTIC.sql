
-- SCHEMA DIAGNOSTIC V1.0
-- Check the current types of identity columns to find the culprit.

SELECT 
    table_name, 
    column_name, 
    data_type 
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND column_name IN ('id', 'user_id', 'customer_id', 'vendor_id', 'rider_id', 'delivery_address_id')
  AND table_name IN ('orders', 'customer_profiles', 'wallets', 'user_addresses', 'delivery_riders', 'vendors');
