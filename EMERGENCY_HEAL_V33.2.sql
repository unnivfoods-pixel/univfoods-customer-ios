-- 🚨 EMERGENCY HEAL (V33.2)
-- 🎯 MISSION: Kill the "{}" address bug.
-- 🎯 MISSION: Restore human-readable names.

BEGIN;

-- 1. UNLOCK SCHEMA
DROP VIEW IF EXISTS public.order_details_v3 CASCADE;

-- 2. DATA HEALING (The "Anti-Curly" Mission)
-- This cleans up any records that were accidentally saved as JSON strings like "{}"
UPDATE public.orders 
SET 
  delivery_address = CASE 
    WHEN delivery_address = '{}' OR delivery_address IS NULL THEN address 
    ELSE delivery_address 
  END,
  address = CASE 
    WHEN address = '{}' OR address IS NULL THEN delivery_address 
    ELSE address 
  END;

-- Second pass: If both are still empty or {}, set a safety fallback
UPDATE public.orders 
SET delivery_address = 'Selected Location'
WHERE (delivery_address = '{}' OR delivery_address IS NULL) 
  AND (address = '{}' OR address IS NULL);

-- 3. REBUILD THE VIEW (Truth Protocol with JSON-stripping)
-- We use a more aggressive COALESCE to ensure we never show {} to the user.
CREATE OR REPLACE VIEW public.order_details_v3 AS
SELECT 
    o.*,
    CASE 
        WHEN o.delivery_address = '{}' THEN o.address
        WHEN o.address = '{}' THEN o.delivery_address
        ELSE COALESCE(o.delivery_address, o.address, 'My Address')
    END as effective_address,
    v.name as vendor_name,
    v.image_url as vendor_image_url,
    jsonb_build_object(
        'name', v.name, 
        'latitude', v.latitude, 
        'longitude', v.longitude
    ) as vendors
FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id::TEXT = v.id::TEXT;

GRANT SELECT ON public.order_details_v3 TO anon, authenticated, service_role;

-- 4. BULLETPROOF PLACE_ORDER
CREATE OR REPLACE FUNCTION public.place_order_v5(
    p_customer_id TEXT, p_vendor_id TEXT, p_items JSONB, p_total DOUBLE PRECISION,
    p_address TEXT, p_lat DOUBLE PRECISION, p_lng DOUBLE PRECISION,
    p_payment_method TEXT, p_instructions TEXT DEFAULT NULL,
    p_address_id TEXT DEFAULT NULL, p_initial_status TEXT DEFAULT 'placed'
)
RETURNS UUID AS $$
DECLARE
    v_order_id UUID;
    v_v_lat DOUBLE PRECISION; v_v_lng DOUBLE PRECISION;
    v_safe_address TEXT;
BEGIN
    -- Protection against empty addresses
    v_safe_address := COALESCE(NULLIF(p_address, '{}'), 'My Location');

    SELECT latitude, longitude INTO v_v_lat, v_v_lng
    FROM public.vendors WHERE id::TEXT = p_vendor_id::TEXT;

    INSERT INTO public.orders (
        customer_id, vendor_id, items, total, 
        address, delivery_address, 
        delivery_lat, delivery_lng, pickup_lat, pickup_lng,
        status, payment_method, payment_status,
        pickup_otp, delivery_otp, delivery_address_id, cooking_instructions
    ) VALUES (
        p_customer_id, p_vendor_id::UUID, p_items, p_total, 
        v_safe_address, v_safe_address, 
        p_lat, p_lng, v_v_lat, v_v_lng,
        p_initial_status, p_payment_method, 'PENDING',
        lpad(floor(random() * 10000)::text, 4, '0'), 
        lpad(floor(random() * 10000)::text, 4, '0'),
        p_address_id::UUID, p_instructions
    ) RETURNING id INTO v_order_id;
    RETURN v_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
