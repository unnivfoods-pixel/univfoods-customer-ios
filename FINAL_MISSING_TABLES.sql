-- ✅ FINAL MISSING TABLES FIX
-- This script ensures ALL tables required by Delivery, Customer, and Admin apps exist.
-- Including 'rider_tracking' which is used for audit logs in Delivery App.

-- ============================================
-- 1. CREATE RIDER TRACKING (Used by Delivery App)
-- ============================================
CREATE TABLE IF NOT EXISTS public.rider_tracking (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES public.orders(id) ON DELETE SET NULL,
    rider_id UUID REFERENCES public.delivery_riders(id) ON DELETE CASCADE,
    latitude FLOAT NOT NULL,
    longitude FLOAT NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT now(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Enable RLS on rider_tracking
ALTER TABLE public.rider_tracking ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Riders can insert tracking" ON public.rider_tracking FOR INSERT WITH CHECK (auth.uid() = rider_id);
CREATE POLICY "Admin can view tracking" ON public.rider_tracking FOR SELECT USING (true);


-- ============================================
-- 2. ENSURE delivery_riders HAS LOCATION COLUMNS
-- ============================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'delivery_riders' AND column_name = 'current_lat') THEN
        ALTER TABLE public.delivery_riders ADD COLUMN current_lat FLOAT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'delivery_riders' AND column_name = 'current_lng') THEN
        ALTER TABLE public.delivery_riders ADD COLUMN current_lng FLOAT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'delivery_riders' AND column_name = 'heading') THEN
        ALTER TABLE public.delivery_riders ADD COLUMN heading FLOAT DEFAULT 0;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'delivery_riders' AND column_name = 'last_location_update') THEN
        ALTER TABLE public.delivery_riders ADD COLUMN last_location_update TIMESTAMP WITH TIME ZONE;
    END IF;
END $$;


-- ============================================
-- 3. ENSURE REALTIME IS ON
-- ============================================
-- We re-run this just to be 100% sure
DO $$
BEGIN
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.delivery_riders; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.rider_tracking; EXCEPTION WHEN OTHERS THEN NULL; END;
END $$;

-- ============================================
-- 4. GRANT PERMISSIONS
-- ============================================
GRANT ALL ON public.rider_tracking TO authenticated;
GRANT ALL ON public.rider_tracking TO anon;
