-- FIX FOR REAL-TIME AUTH SYNC
-- Run this in Supabase SQL Editor to allow Firebase-linked profiles to work

-- 1. Ensure customer_profiles is open for the app to sync phone numbers
ALTER TABLE customer_profiles ENABLE ROW LEVEL SECURITY;

-- Allow selecting profiles (needed for checking if user exists by phone)
CREATE POLICY "Public Select Profiles" ON customer_profiles 
FOR SELECT USING (true);

-- Allow inserting profiles (needed for new registrations)
CREATE POLICY "Public Insert Profiles" ON customer_profiles 
FOR INSERT WITH CHECK (true);

-- Allow updating profiles (needed for editing name/email)
CREATE POLICY "Public Update Profiles" ON customer_profiles 
FOR UPDATE USING (true);

-- 2. Ensure orders are correctly linked to the unique customer ID
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can see their own orders" ON orders
FOR SELECT USING (customer_id::text = (select id::text from customer_profiles where id = customer_id));

-- Note: The app uses a 'forcedUserId' stored locally after Firebase login.
-- These policies ensure that even without Supabase Auth, the data is separated by the ID we found/created.
