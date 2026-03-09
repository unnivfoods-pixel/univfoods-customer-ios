ALTER TABLE customer_profiles DROP CONSTRAINT IF EXISTS customer_profiles_id_fkey; ALTER TABLE customer_profiles ALTER COLUMN id SET DEFAULT gen_random_uuid();
