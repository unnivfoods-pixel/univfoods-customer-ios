-- 1. Add user_id to registrations (if not exists) to link with Auth User
ALTER TABLE registrations ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id);

-- 2. Add user_id to delivery_riders to link with Auth User
ALTER TABLE delivery_riders ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id);

-- 3. Ensure vendors has owner_id (it usually does, but asking to be safe or index it)
-- ALTER TABLE vendors ADD COLUMN IF NOT EXISTS owner_id UUID REFERENCES auth.users(id);

-- 4. Grant permissions if needed (RLS)
-- GRANT ALL ON registrations TO authenticated;
-- GRANT ALL ON registrations TO service_role;
