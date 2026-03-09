-- 🔍 SACRED SCHEMA VERIFICATION
-- Check column types for support system to ensure zero type-mismatch faults.

SELECT 
    table_name, 
    column_name, 
    data_type 
FROM information_schema.columns 
WHERE table_name IN ('support_tickets', 'ticket_messages', 'customer_profiles', 'delivery_riders', 'vendors')
AND column_name IN ('id', 'user_id', 'sender_id', 'ticket_id', 'owner_id');
