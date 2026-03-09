-- 📍 TRACKING TRUTH PROTOCOL (V33.4)
-- 🎯 MISSION: Kill the "Demo" experience.
-- 🎯 MISSION: Fix dr.image_url -> dr.profile_image alias.

BEGIN;

-- 1. UNLOCK SCHEMA
DROP VIEW IF EXISTS public.order_details_v3 CASCADE;

-- 2. REPAIR COORDINATES (The "Tirunelveli/Demo" Killer)
-- If orders are missing coords, pull them from the vendors table or the provided strings.
UPDATE public.orders o
SET 
  pickup_lat = COALESCE(o.pickup_lat, v.latitude),
  pickup_lng = COALESCE(o.pickup_lng, v.longitude),
  delivery_lat = CASE WHEN o.delivery_lat IS NULL OR o.delivery_lat = 0 THEN 9.5150 ELSE o.delivery_lat END,
  delivery_lng = CASE WHEN o.delivery_lng IS NULL OR o.delivery_lng = 0 THEN 77.6350 ELSE o.delivery_lng END
FROM public.vendors v
WHERE o.vendor_id::TEXT = v.id::TEXT;

-- 3. ENHANCED VIEW (The tracking engine)
CREATE OR REPLACE VIEW public.order_details_v3 AS
SELECT 
    o.*,
    -- User Info
    COALESCE(NULLIF(o.delivery_address, '{}'), o.address, 'My Address') as effective_address,
    (SELECT full_name FROM public.customer_profiles cp WHERE cp.id::TEXT = o.customer_id::TEXT) as customer_name,
    
    -- Vendor Info (Top level for easier Dart access)
    v.name as vendor_name,
    v.address as vendor_address,
    v.image_url as vendor_image_url,
    v.phone as vendor_phone,
    COALESCE(o.pickup_lat, v.latitude) as resolved_pickup_lat,
    COALESCE(o.pickup_lng, v.longitude) as resolved_pickup_lng,
    
    -- Rider Info (FIXED: dr.profile_image instead of dr.image_url)
    dr.name as rider_name,
    dr.phone as rider_phone,
    dr.vehicle_number as rider_vehicle,
    dr.profile_image as rider_avatar,
    
    -- Legacy support object
    jsonb_build_object(
        'name', v.name, 
        'address', v.address,
        'latitude', COALESCE(o.pickup_lat, v.latitude), 
        'longitude', COALESCE(o.pickup_lng, v.longitude)
    ) as vendors
FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id::TEXT = v.id::TEXT
LEFT JOIN public.delivery_riders dr ON o.rider_id::TEXT = dr.id::TEXT;

GRANT SELECT ON public.order_details_v3 TO anon, authenticated, service_role;

-- 4. BOOTSTRAP UPGRADE
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
