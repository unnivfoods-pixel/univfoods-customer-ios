-- =========================================================================
-- REALTIME MISSING FEATURES PATCH (V13)
-- Addressing: Favorites, Saved Addresses, Notifications, Language, Filters
-- =========================================================================

-- 1. ADD MISSING COLUMNS TO CUSTOMER PROFILES
ALTER TABLE public.customer_profiles 
ADD COLUMN IF NOT EXISTS chosen_language text DEFAULT 'English',
ADD COLUMN IF NOT EXISTS notification_token text;

-- 2. CREATE USER ADDRESSES TABLE
CREATE TABLE IF NOT EXISTS public.user_addresses (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
    title text NOT NULL, -- 'Home', 'Work', etc.
    address_line text NOT NULL,
    latitude double precision,
    longitude double precision,
    is_default boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. CREATE FAVORITES TABLE
CREATE TABLE IF NOT EXISTS public.favorites (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
    item_id uuid NOT NULL, -- Can be vendor_id or product_id
    item_type text NOT NULL, -- 'VENDOR' or 'PRODUCT'
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(user_id, item_id, item_type)
);

-- 4. CREATE NOTIFICATIONS TABLE
CREATE TABLE IF NOT EXISTS public.notifications (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
    title text NOT NULL,
    body text NOT NULL,
    is_read boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 5. UPGRADE VENDORS FOR FILTERING
ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS is_trending boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS is_top_rated boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS is_pure_veg boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS tags text[]; -- Array of tags like ['curry', 'breads', 'biryani']

-- 6. ENABLE REALTIME
ALTER PUBLICATION supabase_realtime ADD TABLE public.user_addresses;
ALTER PUBLICATION supabase_realtime ADD TABLE public.favorites;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE public.customer_profiles;

-- 7. RLS POLICIES (Users can only see/edit THEIR OWN data)
ALTER TABLE public.user_addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Addresses
CREATE POLICY "Users manage own addresses" ON public.user_addresses
FOR ALL USING (auth.uid() = user_id);

-- Favorites
CREATE POLICY "Users manage own favorites" ON public.favorites
FOR ALL USING (auth.uid() = user_id);

-- Notifications
CREATE POLICY "Users see own notifications" ON public.notifications
FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users update own notifications" ON public.notifications
FOR UPDATE USING (auth.uid() = user_id);

-- 8. SEED SOME TAGS FOR CATEGORIES
UPDATE public.vendors SET tags = ARRAY['curry', 'biryani'] WHERE name ILIKE '%Kingdom%';
UPDATE public.vendors SET tags = ARRAY['breads', 'curry'] WHERE name ILIKE '%House%';
UPDATE public.vendors SET is_trending = true, is_top_rated = true WHERE rating >= 4.5;
UPDATE public.vendors SET is_pure_veg = true WHERE name ILIKE '%Veg%';

NOTIFY pgrst, 'reload schema';
