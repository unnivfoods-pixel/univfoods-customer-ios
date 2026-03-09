-- Enable Realtime for user_addresses
ALTER PUBLICATION supabase_realtime ADD TABLE user_addresses;

-- Ensure public/authenticated users can delete their own addresses
CREATE POLICY "Users can delete own addresses" ON user_addresses
    FOR DELETE TO authenticated
    USING (auth.uid() = user_id);
