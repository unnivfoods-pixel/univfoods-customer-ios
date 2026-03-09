-- HEAL CUSTOMER PROFILES: Backfill from Orders
-- This script creates a profile for every user who has placed an order,
-- using the snapshots we have in the orders table.

INSERT INTO customer_profiles (id, full_name, phone, created_at)
SELECT DISTINCT 
    COALESCE(customer_id, user_id) as id,
    MAX(customer_name_snapshot) as full_name,
    MAX(customer_phone_snapshot) as phone,
    NOW() as created_at
FROM orders
WHERE (customer_id IS NOT NULL OR user_id IS NOT NULL)
ON CONFLICT (id) DO UPDATE SET
    full_name = COALESCE(customer_profiles.full_name, EXCLUDED.full_name),
    phone = COALESCE(customer_profiles.phone, EXCLUDED.phone);

-- Also ensure the orders table has the new columns for future-proofing
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_phone TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_pincode TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_house_number TEXT;
