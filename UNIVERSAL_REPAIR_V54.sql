-- UNIVERSAL REPAIR V54: AGGRESSIVE IDENTITY & ADDRESS RECOVERY
-- This script ensures the database handles identity fallbacks for guest users
-- and correctly maps the new granular address fields (phone, pincode, house).

-- 1. Ensure columns exist (Defensive)
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='delivery_phone') THEN
        ALTER TABLE orders ADD COLUMN delivery_phone TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='delivery_pincode') THEN
        ALTER TABLE orders ADD COLUMN delivery_pincode TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='delivery_house_number') THEN
        ALTER TABLE orders ADD COLUMN delivery_house_number TEXT;
    END IF;
END $$;

-- 2. Update Order Details View with Multi-Stage Fallback
CREATE OR REPLACE VIEW order_details_v3 AS
SELECT 
    o.*,
    v.name as vendor_name,
    v.address as vendor_address,
    v.image_url as vendor_image,
    -- Aggressive Identity Resolution
    COALESCE(
        p.full_name, 
        o.customer_name_snapshot, 
        o.customer_name_legacy, 
        o.delivery_phone, 
        o.customer_phone_snapshot,
        o.customer_id,
        'Guest User'
    ) as display_customer_name,
    COALESCE(
        o.delivery_phone,
        o.customer_phone_snapshot,
        o.customer_phone_legacy,
        p.phone,
        CASE WHEN o.customer_id ~ '^\d{10}$' THEN o.customer_id ELSE NULL END
    ) as display_customer_phone,
    -- Address Reconstruction
    COALESCE(o.delivery_address, o.address) as display_address,
    COALESCE(o.delivery_pincode, (regexp_matches(COALESCE(o.delivery_address, o.address), '\b\d{6}\b'))[1]) as display_pincode
FROM orders o
LEFT JOIN vendors v ON o.vendor_id::text = v.id::text
LEFT JOIN customer_profiles p ON o.customer_id::text = p.id::text;

-- 3. Upgrade Place Order RPC to V11 (Strict capture)
CREATE OR REPLACE FUNCTION place_order_v11(p_params JSONB)
RETURNS UUID AS $$
DECLARE
    v_order_id UUID;
BEGIN
    INSERT INTO orders (
        customer_id, 
        vendor_id, 
        total, 
        status, 
        payment_method, 
        payment_status,
        delivery_address, 
        delivery_lat, 
        delivery_lng,
        delivery_phone,
        delivery_pincode,
        delivery_house_number,
        customer_name_snapshot,
        customer_phone_snapshot,
        items,
        cooking_instructions,
        created_at
    ) VALUES (
        (p_params->>'customer_id')::TEXT,
        (p_params->>'vendor_id')::TEXT,
        (p_params->>'total')::NUMERIC,
        'placed',
        COALESCE(p_params->>'payment_method', 'COD'),
        CASE WHEN (p_params->>'payment_method') = 'COD' THEN 'pending' ELSE 'paid' END,
        (p_params->>'address')::TEXT,
        (p_params->>'lat')::NUMERIC,
        (p_params->>'lng')::NUMERIC,
        (p_params->>'delivery_phone')::TEXT,
        (p_params->>'delivery_pincode')::TEXT,
        (p_params->>'delivery_house_number')::TEXT,
        (p_params->>'customer_name')::TEXT,
        (p_params->>'customer_phone')::TEXT,
        (p_params->'items')::JSONB,
        (p_params->>'instructions')::TEXT,
        NOW()
    ) RETURNING id INTO v_order_id;

    RETURN v_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
