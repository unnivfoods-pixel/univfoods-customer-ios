-- 🚨 UNIVERSAL REPAIR V53 (REAL COLUMN FIX & IDENTITY ALIGNMENT)
-- The previous V52 tried to insert into 'customer_name' which doesn't exist in the 'orders' table.
-- The correct column names are 'customer_name_snapshot' and 'customer_phone_snapshot'.

BEGIN;

-- [A] PLACE ORDER RPC FINAL FIX (v10 - Corrected Columns)
CREATE OR REPLACE FUNCTION public.place_order_v10(p_params JSONB)
RETURNS UUID AS $$
DECLARE v_id UUID;
BEGIN
    INSERT INTO public.orders (
        customer_id, 
        user_id, 
        vendor_id, 
        items, 
        total, 
        status, 
        payment_method, 
        payment_status, 
        delivery_address, 
        delivery_lat, 
        delivery_lng, 
        cooking_instructions, 
        delivery_address_id, 
        delivery_phone, 
        delivery_pincode, 
        delivery_house_number, 
        customer_name_snapshot, 
        customer_phone_snapshot,
        created_at
    ) VALUES (
        (p_params->>'customer_id')::TEXT, 
        (p_params->>'customer_id')::TEXT, 
        (p_params->>'vendor_id')::TEXT, 
        (p_params->'items'), 
        (p_params->>'total')::NUMERIC, 
        'PLACED', 
        (p_params->>'payment_method')::TEXT, 
        'PENDING', 
        (p_params->>'address')::TEXT, 
        (p_params->>'lat')::DOUBLE PRECISION, 
        (p_params->>'lng')::DOUBLE PRECISION, 
        (COALESCE(p_params->>'instructions', ''))::TEXT, 
        (p_params->>'address_id')::TEXT, 
        (p_params->>'delivery_phone')::TEXT,
        (p_params->>'delivery_pincode')::TEXT,
        (p_params->>'delivery_house_number')::TEXT,
        (p_params->>'customer_name')::TEXT,
        (p_params->>'customer_phone')::TEXT,
        NOW()
    ) RETURNING id INTO v_id;
    RETURN v_id;
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- Aliasing place_order_v9 for retro-compatibility but with v10 corrected logic
CREATE OR REPLACE VIEW public.order_details_v3 AS
SELECT 
    o.*,
    o.id::TEXT as order_id,
    v.name as vendor_name,
    v.logo_url as vendor_logo_url,
    v.banner_url as vendor_banner_url,
    v.phone as vendor_phone,
    r.name as rider_name,
    r.phone as rider_phone,
    r.id::TEXT as rider_id_text,
    COALESCE(p.full_name, o.customer_name_snapshot, 'Guest User') as customer_name,
    COALESCE(p.phone, o.customer_phone_snapshot, o.delivery_phone, '') as customer_phone,
    COALESCE(o.status, 'PLACED') as status_display,
    o.created_at as order_created_at
FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id::TEXT = v.id::TEXT
LEFT JOIN public.delivery_riders r ON o.rider_id::TEXT = r.id::TEXT
LEFT JOIN public.customer_profiles p ON o.customer_id::TEXT = p.id::TEXT;

COMMIT;
