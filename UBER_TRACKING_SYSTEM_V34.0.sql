-- 🛰️ UBER-LEVEL REALTIME TRACKING SYSTEM (V34.0)
-- 🎯 MISSION: Full Lifecycle Tracking, Rider Analytics, and Instant Sync.

BEGIN;

-- 1. UPGRADE ORDERS TABLE (The Lifecycle Engine)
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS accepted_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS assigned_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS pickup_time TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS eta_minutes INTEGER,
ADD COLUMN IF NOT EXISTS preparation_time_seconds INTEGER,
ADD COLUMN IF NOT EXISTS delivery_time_seconds INTEGER;

-- 2. UPGRADE DELIVERY RIDERS (The Performance Layer)
-- Ensure all rider fields are present for the Customer App to see.
ALTER TABLE public.delivery_riders 
ADD COLUMN IF NOT EXISTS rating NUMERIC DEFAULT 4.8,
ADD COLUMN IF NOT EXISTS total_deliveries INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS profile_image TEXT,
ADD COLUMN IF NOT EXISTS vehicle_number TEXT,
ADD COLUMN IF NOT EXISTS vehicle_type TEXT,
ADD COLUMN IF NOT EXISTS phone TEXT;

-- 3. CHAT INFRASTRUCTURE (Order-Centric)
CREATE TABLE IF NOT EXISTS public.order_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES public.orders(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL,
    sender_role TEXT NOT NULL, -- 'customer', 'rider', 'vendor'
    message TEXT NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 4. LIVE TRACKING LOGS (High Frequency Snapshots)
-- Already exists as order_tracking, but ensuring it's robust.
CREATE TABLE IF NOT EXISTS public.order_live_tracking (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES public.orders(id) ON DELETE CASCADE,
    rider_id UUID REFERENCES public.delivery_riders(id),
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    heading DOUBLE PRECISION DEFAULT 0,
    speed DOUBLE PRECISION DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.order_live_tracking REPLICA IDENTITY FULL;

-- 5. THE ULTIMATE VIEW (The "Truth" Protocol)
DROP VIEW IF EXISTS public.order_details_v3 CASCADE;

CREATE OR REPLACE VIEW public.order_details_v3 AS
SELECT 
    o.*,
    -- Effective Address (Human Readable)
    COALESCE(NULLIF(o.delivery_address, '{}'), o.address, 'My Address') as effective_address,
    
    -- Customer Info
    cp.full_name as customer_name,
    cp.phone as customer_phone,
    cp.avatar_url as customer_avatar,
    
    -- Vendor Info (Top level)
    v.name as vendor_name,
    v.address as vendor_address,
    v.phone as vendor_phone,
    v.image_url as vendor_image_url,
    COALESCE(o.pickup_lat, v.latitude) as resolved_pickup_lat,
    COALESCE(o.pickup_lng, v.longitude) as resolved_pickup_lng,
    
    -- Rider Info (Joined for instant display)
    dr.name as rider_name,
    dr.phone as rider_phone,
    dr.vehicle_number as rider_vehicle,
    dr.profile_image as rider_avatar,
    dr.rating as rider_rating,
    dr.current_lat as rider_live_lat,
    dr.current_lng as rider_live_lng,
    dr.last_gps_update as rider_last_seen,
    
    -- Status Display Mapping
    CASE 
        WHEN o.status = 'placed' THEN 'Order Placed'
        WHEN o.status = 'accepted' THEN 'Order Accepted'
        WHEN o.status = 'preparing' THEN 'Preparing Food'
        WHEN o.status = 'ready' THEN 'Ready for Pickup'
        WHEN o.status = 'picked_up' THEN 'Picked Up'
        WHEN o.status = 'on_the_way' THEN 'On The Way'
        WHEN o.status = 'arriving' THEN 'Arriving Now'
        WHEN o.status = 'delivered' THEN 'Delivered'
        ELSE UPPER(o.status)
    END as status_display,

    -- Dynamic Step (1-5)
    CASE 
        WHEN o.status IN ('placed', 'accepted') THEN 1
        WHEN o.status = 'preparing' THEN 2
        WHEN o.status IN ('ready', 'picked_up') THEN 3
        WHEN o.status = 'on_the_way' THEN 4
        WHEN o.status = 'delivered' THEN 5
        ELSE 1
    END as current_step
FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id::TEXT = v.id::TEXT
LEFT JOIN public.customer_profiles cp ON o.customer_id::TEXT = cp.id::TEXT
LEFT JOIN public.delivery_riders dr ON o.rider_id::TEXT = dr.id::TEXT;

GRANT SELECT ON public.order_details_v3 TO anon, authenticated, service_role;

-- 6. REALTIME REGULATOR (Enable Live Push)
BEGIN;
  DO $$ 
  BEGIN
    -- Core Tables to Realtime
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.orders; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.order_live_tracking; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.order_messages; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.delivery_riders; EXCEPTION WHEN OTHERS THEN NULL; END;
  END $$;
COMMIT;

-- 7. BOOTSTRAP UPGRADE (Ensuring fresh data on app open)
DROP FUNCTION IF EXISTS public.get_unified_bootstrap_data(TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.get_unified_bootstrap_data(p_user_id TEXT, p_role TEXT DEFAULT 'customer')
RETURNS JSONB AS $$
DECLARE
    v_profile JSONB;
    v_orders JSONB;
    v_wallet JSONB;
    v_favorites JSONB;
BEGIN
    SELECT row_to_json(p) INTO v_profile FROM public.customer_profiles p WHERE id::TEXT = p_user_id;
    
    SELECT json_agg(o) INTO v_orders 
    FROM (SELECT * FROM public.order_details_v3 WHERE customer_id::TEXT = p_user_id ORDER BY created_at DESC LIMIT 20) o;
    
    SELECT row_to_json(w) INTO v_wallet FROM public.wallets w WHERE user_id::TEXT = p_user_id;
    
    SELECT json_agg(f.product_id) INTO v_favorites FROM public.user_favorites f WHERE user_id::TEXT = p_user_id;

    RETURN jsonb_build_object(
        'profile', COALESCE(v_profile, '{}'::json),
        'orders', COALESCE(v_orders, '[]'::json),
        'wallet', COALESCE(v_wallet, '{"balance": 0}'::json),
        'favorites', COALESCE(v_favorites, '[]'::json)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
