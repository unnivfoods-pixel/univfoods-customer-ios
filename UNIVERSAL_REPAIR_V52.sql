-- 🚨 UNIVERSAL REPAIR V52 (ADDRESS & IDENTITY COMPLETION)
-- 1. Upgrade View to join with Customer Profiles for Admin Clarity.
-- 2. Upgrade Place Order RPC to handle granular address details.

BEGIN;

-- [A] VIEW REBUILD (With Identity Injection)
DROP VIEW IF EXISTS public.order_tracking_details_v1 CASCADE;
DROP VIEW IF EXISTS public.order_details_v3 CASCADE;

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
    p.full_name as customer_name,
    p.phone as customer_phone,
    COALESCE(o.status, 'PLACED') as status_display,
    o.created_at as order_created_at
FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id::TEXT = v.id::TEXT
LEFT JOIN public.delivery_riders r ON o.rider_id::TEXT = r.id::TEXT
LEFT JOIN public.customer_profiles p ON o.customer_id::TEXT = p.id::TEXT;

-- Compatibility alias
CREATE OR REPLACE VIEW public.order_tracking_details_v1 AS SELECT * FROM public.order_details_v3;

-- [B] PLACE ORDER RPC UPGRADE (v10 - The Full Spec)
-- This RPC handles the granular address details and customer snapshots if provided.
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
        customer_name, 
        customer_phone,
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

-- Aliasing place_order_v9 for retro-compatibility but with v10 logic
CREATE OR REPLACE FUNCTION public.place_order_v9(p_params JSONB)
RETURNS UUID AS $$
BEGIN
    RETURN public.place_order_v10(p_params);
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
