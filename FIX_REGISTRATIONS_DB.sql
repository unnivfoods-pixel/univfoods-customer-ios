-- Ensure registration_requests table has all necessary columns including 'type' and 'password'
DO $$ 
BEGIN
    -- Create table if it doesn't exist
    IF NOT EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'registration_requests') THEN
        CREATE TABLE registration_requests (
            id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            name TEXT,
            email TEXT,
            phone TEXT,
            password TEXT,
            message TEXT,
            status TEXT DEFAULT 'pending',
            type TEXT DEFAULT 'vendor',
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );
    ELSE
        -- Add missing columns if table exists
        IF NOT EXISTS (SELECT FROM INFORMATION_SCHEMA.COLUMNS WHERE table_name = 'registration_requests' AND column_name = 'type') THEN
            ALTER TABLE registration_requests ADD COLUMN type TEXT DEFAULT 'vendor';
        END IF;
        
        IF NOT EXISTS (SELECT FROM INFORMATION_SCHEMA.COLUMNS WHERE table_name = 'registration_requests' AND column_name = 'password') THEN
            ALTER TABLE registration_requests ADD COLUMN password TEXT;
        END IF;
    END IF;
END $$;
