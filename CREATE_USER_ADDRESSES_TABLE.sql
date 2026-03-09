-- Create user_addresses table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.user_addresses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL, -- 'Home', 'Work', 'Other'
    address_line TEXT NOT NULL,
    contact_name TEXT,
    contact_phone TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.user_addresses ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view own addresses"
    ON public.user_addresses FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own addresses"
    ON public.user_addresses FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own addresses"
    ON public.user_addresses FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own addresses"
    ON public.user_addresses FOR DELETE
    USING (auth.uid() = user_id);

-- Create index
CREATE INDEX IF NOT EXISTS idx_user_addresses_user_id ON public.user_addresses(user_id);
