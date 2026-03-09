-- ✅ FIX MISSING TABLES & ENABLE REALTIME
-- This script creates the missing 'rider_locations' table and then enables realtime.

-- ============================================
-- 1. CREATE MISSING TABLES
-- ============================================

CREATE TABLE IF NOT EXISTS public.delivery_riders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name TEXT,
    phone TEXT,
    email TEXT,
    avatar_url TEXT,
    vehicle_type TEXT,
    vehicle_number TEXT,
    status TEXT DEFAULT 'offline', -- 'online', 'offline', 'busy'
    is_available BOOLEAN DEFAULT false,
    current_lat FLOAT,
    current_lng FLOAT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.rider_locations (
    rider_id UUID PRIMARY KEY REFERENCES public.delivery_riders(id) ON DELETE CASCADE,
    latitude FLOAT NOT NULL,
    longitude FLOAT NOT NULL,
    heading FLOAT DEFAULT 0,
    speed FLOAT DEFAULT 0,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL, -- Can be customer_id, rider_id, or vendor_id
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    type TEXT NOT NULL, -- 'order_update', 'promo', 'system'
    is_read BOOLEAN DEFAULT false,
    data JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- ============================================
-- 2. ENABLE REALTIME (SAFE MODE)
-- ============================================

DO $$
BEGIN
    -- Add tables to realtime publication (ignore if already exists)
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.orders; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.order_items; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.vendors; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.menu_items; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.categories; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.customer_profiles; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.delivery_riders; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.user_addresses; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.payments; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.rider_locations; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.delivery_zones; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.banners; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.vendor_reviews; EXCEPTION WHEN OTHERS THEN NULL; END;
END $$;

-- ============================================
-- 3. FIX RLS POLICIES
-- ============================================

-- Enable RLS on tables
ALTER TABLE public.rider_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.delivery_riders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Rider Locations Policies
DROP POLICY IF EXISTS "Anyone can view rider locations" ON public.rider_locations;
CREATE POLICY "Anyone can view rider locations" ON public.rider_locations FOR SELECT USING (true);

DROP POLICY IF EXISTS "Riders can update own location" ON public.rider_locations;
CREATE POLICY "Riders can update own location" ON public.rider_locations FOR ALL USING (auth.uid() = rider_id);

-- Delivery Riders Policies
DROP POLICY IF EXISTS "Admin can view all riders" ON public.delivery_riders;
CREATE POLICY "Admin can view all riders" ON public.delivery_riders FOR SELECT USING (true);

DROP POLICY IF EXISTS "Riders can view own profile" ON public.delivery_riders;
CREATE POLICY "Riders can view own profile" ON public.delivery_riders FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Riders can update own profile" ON public.delivery_riders;
CREATE POLICY "Riders can update own profile" ON public.delivery_riders FOR UPDATE USING (auth.uid() = id);

-- Notifications Policies
DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
CREATE POLICY "Users can view own notifications" ON public.notifications FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;
CREATE POLICY "Users can update own notifications" ON public.notifications FOR UPDATE USING (auth.uid() = user_id);

-- ============================================
-- 4. GRANT PERMISSIONS
-- ============================================

GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT SELECT ON public.orders TO anon, authenticated;
GRANT SELECT ON public.vendors TO anon, authenticated;
GRANT SELECT ON public.menu_items TO anon, authenticated;
GRANT SELECT ON public.categories TO anon, authenticated;
GRANT SELECT ON public.delivery_riders TO anon, authenticated;
GRANT SELECT ON public.rider_locations TO anon, authenticated;
GRANT SELECT ON public.banners TO anon, authenticated;
GRANT ALL ON public.customer_profiles TO authenticated;
GRANT ALL ON public.user_addresses TO authenticated;
GRANT ALL ON public.notifications TO authenticated;
GRANT ALL ON public.payments TO authenticated;

-- ============================================
-- CHECK SUCCESS
-- ============================================

SELECT 
    tablename,
    'READY ✅' as status
FROM 
    pg_publication_tables 
WHERE 
    pubname = 'supabase_realtime'
ORDER BY 
    tablename;
