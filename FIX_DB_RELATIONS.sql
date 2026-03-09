-- 1. Create user_favorites table if not exists
CREATE TABLE IF NOT EXISTS public.user_favorites (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id),
    vendor_id UUID REFERENCES public.vendors(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    UNIQUE(user_id, vendor_id)
);

-- 2. Cleanup orphaned orders (orders with customer_id that doesn't exist in customer_profiles)
-- This ensures the foreign key constraint doesn't fail.
INSERT INTO public.customer_profiles (id, full_name, email)
SELECT DISTINCT customer_id, 'Guest User', 'guest@univfoods.in'
FROM public.orders
WHERE customer_id NOT IN (SELECT id FROM public.customer_profiles)
AND customer_id IS NOT NULL
ON CONFLICT (id) DO NOTHING;

-- Now add the foreign key constraint safely
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_orders_customer_profiles'
    ) THEN
        ALTER TABLE public.orders 
        ADD CONSTRAINT fk_orders_customer_profiles 
        FOREIGN KEY (customer_id) REFERENCES public.customer_profiles(id);
    END IF;
END $$;

-- 3. Add some default images/data if missing for demos
UPDATE public.vendors SET image_url = 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4' WHERE image_url IS NULL;

-- 4. Enable Realtime for user_favorites
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'user_favorites') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.user_favorites;
    END IF;
END $$;
