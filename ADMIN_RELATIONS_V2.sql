-- =============================================================================
-- ADMIN RELATION FIX V2: Link Orders to Customer Profiles
-- =============================================================================

-- 1. Ensure foreign key exists from orders.customer_id to customer_profiles.id
-- This is required for Supabase joined queries like .select('*, customer_profiles(*)')
ALTER TABLE "orders" DROP CONSTRAINT IF EXISTS "orders_customer_id_fkey";
ALTER TABLE "orders" ADD CONSTRAINT "orders_customer_id_fkey" 
FOREIGN KEY ("customer_id") REFERENCES "customer_profiles"("id") ON DELETE SET NULL;

-- 2. Optional: Ensure orders.delivery_partner_id to delivery_riders.id
ALTER TABLE "orders" DROP CONSTRAINT IF EXISTS "orders_delivery_partner_id_fkey";
ALTER TABLE "orders" ADD CONSTRAINT "orders_delivery_partner_id_fkey"
FOREIGN KEY ("delivery_partner_id") REFERENCES "delivery_riders"("id") ON DELETE SET NULL;

-- 3. Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
