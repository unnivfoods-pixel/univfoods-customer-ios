-- 📍 MASTER ADDRESS & TRACKING SYNC (V33.1)
-- 🎯 MISSION: Fix "Address not coming" in Order Details & Tracking.
-- 🎯 MISSION: Kill "JSONB vs TEXT" type mismatch in delivery_address.

BEGIN;

-- 1. SCHEMA HEALING (Alignment)
-- Drop views that depend on the orders table before altering types
DROP VIEW IF EXISTS public.order_details_v3 CASCADE;
DROP VIEW IF EXISTS public.order_details_v2 CASCADE;
DROP VIEW IF EXISTS public.order_details_v1 CASCADE;

DO $$ 
DECLARE 
    v_col_type TEXT;
BEGIN
    -- Check if column exists and get its type
    SELECT data_type INTO v_col_type 
    FROM information_schema.columns 
    WHERE table_name='orders' AND column_name='delivery_address';

    IF v_col_type IS NULL THEN
        -- Add as TEXT if missing
        ALTER TABLE public.orders ADD COLUMN delivery_address TEXT;
    ELSIF v_col_type != 'text' AND v_col_type != 'character varying' THEN
        -- Force conversion to TEXT if it's mistakenly JSONB or another type
        ALTER TABLE public.orders ALTER COLUMN delivery_address TYPE TEXT USING delivery_address::TEXT;
    END IF;
    
    -- Sync existing records
    UPDATE public.orders SET delivery_address = address WHERE (delivery_address IS NULL OR delivery_address = '') AND address IS NOT NULL;
    UPDATE public.orders SET address = delivery_address WHERE (address IS NULL OR address = '') AND delivery_address IS NOT NULL;
END $$;

-- 2. DUAL-INSERT ENGINE (Upgrade place_order_v5)
-- We now insert the address into BOTH columns to satisfy every screen.
CREATE OR REPLACE FUNCTION public.place_order_v5(
    p_customer_id TEXT,
    p_vendor_id TEXT,
    p_items JSONB,
    p_total DOUBLE PRECISION,
    p_address TEXT,
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION,
    p_payment_method TEXT,
    p_instructions TEXT DEFAULT NULL,
    p_address_id TEXT DEFAULT NULL,
    p_initial_status TEXT DEFAULT 'placed'
)
RETURNS UUID AS $$
DECLARE
    v_order_id UUID;
    v_v_lat DOUBLE PRECISION;
    v_v_lng DOUBLE PRECISION;
BEGIN
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
        p_address, p_address, 
        p_lat, p_lng, v_v_lat, v_v_lng,
        p_initial_status, p_payment_method, 'PENDING',
        lpad(floor(random() * 10000)::text, 4, '0'), 
        lpad(floor(random() * 10000)::text, 4, '0'),
        p_address_id::UUID, p_instructions
    ) RETURNING id INTO v_order_id;

    RETURN v_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. ENHANCED VIEW (For high-fidelity search)
CREATE OR REPLACE VIEW public.order_details_v3 AS
SELECT 
    o.*,
    COALESCE(o.delivery_address, o.address, 'My Address') as effective_address,
    v.name as vendor_name,
    v.phone as vendor_phone,
    v.address as vendor_address_text,
    v.image_url as vendor_image_url,
    jsonb_build_object(
        'name', v.name,
        'image_url', v.image_url,
        'address', v.address,
        'phone', v.phone,
        'latitude', v.latitude,
        'longitude', v.longitude
    ) as vendors,
    (SELECT full_name FROM public.customer_profiles cp WHERE cp.id::TEXT = o.customer_id::TEXT) as profile_name
FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id::TEXT = v.id::TEXT;

GRANT SELECT ON public.order_details_v3 TO anon, authenticated, service_role;

COMMIT;
