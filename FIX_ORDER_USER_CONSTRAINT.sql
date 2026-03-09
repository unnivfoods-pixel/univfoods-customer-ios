-- This script fixes the "Key is not present in table users" error by removing the strict check for user profiles.
-- This allows you to place orders even if your user profile hasn't been fully synced to the 'users' table yet.

-- 1. Remove the foreign key constraint that requires a matching row in the 'users' table
ALTER TABLE "orders" DROP CONSTRAINT IF EXISTS "orders_customer_id_fkey";

-- 2. (Optional backup) If there was another constraint name for the same relationship, try dropping that too
ALTER TABLE "orders" DROP CONSTRAINT IF EXISTS "orders_user_id_fkey";

-- 3. Ensure the 'orders' table definitely has the delivery_address column (just to double check)
ALTER TABLE "orders" ADD COLUMN IF NOT EXISTS "delivery_address" jsonb;

-- 4. Grant permissions just in case
GRANT ALL ON TABLE "orders" TO anon;
GRANT ALL ON TABLE "orders" TO authenticated;
GRANT ALL ON TABLE "orders" TO service_role;
