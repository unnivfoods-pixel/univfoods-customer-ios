-- Add user_id column to registrations specific for linking with Supabase Auth
ALTER TABLE registrations ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id);

-- Make email required in registrations if not already
ALTER TABLE registrations ALTER COLUMN email SET NOT NULL;
