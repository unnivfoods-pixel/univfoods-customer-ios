-- ✅ MASTER DB FIX: COMPLETE REALTIME & MISSING TABLES
-- Run this SINGLE script to fix 'rider_locations' errors and enable Full Realtime for ALL apps.
-- Includes Settlements, Payments, and Delivery Zones.

-- ============================================
-- 1. CREATE MISSING TABLES
-- ============================================

-- A. delivery_riders (if not exists, or ensures columns later)
CREATE TABLE IF NOT EXISTS public.delivery_riders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT,
    phone TEXT,
    email TEXT,
    profile_image TEXT,
    vehicle_type TEXT,
    vehicle_number TEXT,
    status TEXT DEFAULT 'offline',
    is_available BOOLEAN DEFAULT false,
    is_approved BOOLEAN DEFAULT false,
    rating FLOAT DEFAULT 5.0,
    current_lat FLOAT,
    current_lng FLOAT,
    heading FLOAT DEFAULT 0,
    last_location_update TIMESTAMP WITH TIME ZONE,
    wallet_balance FLOAT DEFAULT 0,
    cod_held FLOAT DEFAULT 0,
    total_earnings FLOAT DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- B. rider_locations (The table that caused the error)
CREATE TABLE IF NOT EXISTS public.rider_locations (
    rider_id UUID PRIMARY KEY REFERENCES public.delivery_riders(id) ON DELETE CASCADE,
    latitude FLOAT NOT NULL,
    longitude FLOAT NOT NULL,
    heading FLOAT DEFAULT 0,
    speed FLOAT DEFAULT 0,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- C. rider_tracking (Used by Delivery App logs)
CREATE TABLE IF NOT EXISTS public.rider_tracking (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES public.orders(id) ON DELETE SET NULL,
    rider_id UUID REFERENCES public.delivery_riders(id) ON DELETE CASCADE,
    latitude FLOAT NOT NULL,
    longitude FLOAT NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT now(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- D. notifications
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    type TEXT NOT NULL,
    is_read BOOLEAN DEFAULT false,
    data JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- E. Payout Tables (for Settlements)
CREATE TABLE IF NOT EXISTS public.vendor_payouts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_id UUID REFERENCES public.vendors(id),
    amount FLOAT NOT NULL,
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.driver_payouts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rider_id UUID REFERENCES public.delivery_riders(id),
    amount FLOAT NOT NULL,
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- ============================================
-- 2. ENSURE COLUMNS EXIST (Safe Updates)
-- ============================================
DO $$
BEGIN
    -- delivery_riders columns
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'delivery_riders' AND column_name = 'current_lat') THEN
        ALTER TABLE public.delivery_riders ADD COLUMN current_lat FLOAT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'delivery_riders' AND column_name = 'current_lng') THEN
        ALTER TABLE public.delivery_riders ADD COLUMN current_lng FLOAT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'delivery_riders' AND column_name = 'heading') THEN
        ALTER TABLE public.delivery_riders ADD COLUMN heading FLOAT DEFAULT 0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'delivery_riders' AND column_name = 'is_approved') THEN
        ALTER TABLE public.delivery_riders ADD COLUMN is_approved BOOLEAN DEFAULT false;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'delivery_riders' AND column_name = 'wallet_balance') THEN
        ALTER TABLE public.delivery_riders ADD COLUMN wallet_balance FLOAT DEFAULT 0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'delivery_riders' AND column_name = 'cod_held') THEN
        ALTER TABLE public.delivery_riders ADD COLUMN cod_held FLOAT DEFAULT 0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'delivery_riders' AND column_name = 'total_earnings') THEN
        ALTER TABLE public.delivery_riders ADD COLUMN total_earnings FLOAT DEFAULT 0;
    END IF;

    -- vendors columns (for Settlements)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vendors' AND column_name = 'wallet_balance') THEN
        ALTER TABLE public.vendors ADD COLUMN wallet_balance FLOAT DEFAULT 0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vendors' AND column_name = 'total_earnings') THEN
        ALTER TABLE public.vendors ADD COLUMN total_earnings FLOAT DEFAULT 0;
    END IF;
END $$;

-- ============================================
-- 3. ENABLE REALTIME (Comprehensive)
-- ============================================
DO $$
BEGIN
    -- Core
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.orders; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.order_items; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.vendors; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.menu_items; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.categories; EXCEPTION WHEN OTHERS THEN NULL; END;
    
    -- Users & Profiles
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.customer_profiles; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.user_addresses; EXCEPTION WHEN OTHERS THEN NULL; END;
    
    -- Delivery
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.delivery_riders; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.rider_locations; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.rider_tracking; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.delivery_zones; EXCEPTION WHEN OTHERS THEN NULL; END;
    
    -- System & Financials
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.payments; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.banners; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.vendor_reviews; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.vendor_payouts; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.driver_payouts; EXCEPTION WHEN OTHERS THEN NULL; END;
END $$;

-- ============================================
-- 4. ENABLE RLS & PERMISSIONS
-- ============================================

-- Enable RLS
ALTER TABLE public.delivery_riders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rider_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rider_tracking ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendor_payouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_payouts ENABLE ROW LEVEL SECURITY;

-- Policies (Drop first to avoid conflicts)
DROP POLICY IF EXISTS "Public View Riders" ON public.delivery_riders;
CREATE POLICY "Public View Riders" ON public.delivery_riders FOR SELECT USING (true);

DROP POLICY IF EXISTS "Riders Update Self" ON public.delivery_riders;
CREATE POLICY "Riders Update Self" ON public.delivery_riders FOR UPDATE USING (auth.uid() = id);

DROP POLICY IF EXISTS "Riders Insert Tracking" ON public.rider_tracking;
CREATE POLICY "Riders Insert Tracking" ON public.rider_tracking FOR INSERT WITH CHECK (auth.uid() = rider_id);

DROP POLICY IF EXISTS "Public View Tracking" ON public.rider_tracking;
CREATE POLICY "Public View Tracking" ON public.rider_tracking FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public View Rider Locations" ON public.rider_locations;
CREATE POLICY "Public View Rider Locations" ON public.rider_locations FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users View Own Notifications" ON public.notifications;
CREATE POLICY "Users View Own Notifications" ON public.notifications FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users Update Own Notifications" ON public.notifications;
CREATE POLICY "Users Update Own Notifications" ON public.notifications FOR UPDATE USING (auth.uid() = user_id);

-- Grants
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON public.delivery_riders TO anon, authenticated;
GRANT ALL ON public.rider_locations TO anon, authenticated;
GRANT ALL ON public.rider_tracking TO anon, authenticated;
GRANT ALL ON public.notifications TO anon, authenticated;
GRANT ALL ON public.vendor_payouts TO anon, authenticated;
GRANT ALL ON public.driver_payouts TO anon, authenticated;

-- ============================================
-- 5. VERIFICATION
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
