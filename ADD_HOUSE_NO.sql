-- Add house_number to user_addresses
ALTER TABLE user_addresses ADD COLUMN IF NOT EXISTS house_number TEXT;
ALTER TABLE user_addresses ADD COLUMN IF NOT EXISTS phone_number_snapshot TEXT;
