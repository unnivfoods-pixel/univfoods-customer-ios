-- 📡 NEURAL IDENTITY HARMONY & REALTIME FIX (V11.9.5)
-- Purpose: 100% Fix for Vendor Real-time Orders and Identity Linkage

BEGIN;

-- 1. CLEANUP OLD VENDOR RECORDS
-- We want a clean slate for the Royal Curry House identity.
DELETE FROM public.vendors WHERE name = 'Royal Curry House';
DELETE FROM public.vendors WHERE owner_id = '00000000-0000-0000-0000-000000000001';

-- 2. INSERT STABLE PRODUCTION IDENTITY
-- This UUID '11111111...' will be the permanent ID for the demo vendor.
INSERT INTO public.vendors (
    id,
    name, 
    address, 
    latitude, 
    longitude, 
    status, 
    delivery_radius_km, 
    rating, 
    cuisine_type, 
    is_pure_veg, 
    image_url, 
    banner_url,
    owner_id,
    is_approved,
    approval_status
) VALUES 
(
    '11111111-1111-1111-1111-111111111111'::uuid,
    'Royal Curry House', 
    '123 Main Bazaar, Srivilliputhur', 
    9.5127, 
    77.6337, 
    'ONLINE', 
    999.0, 
    4.8, 
    'South Indian, Chettinad', 
    FALSE,
    'https://images.unsplash.com/photo-1589302168068-964664d93dc0?w=800',
    'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=800',
    '00000000-0000-0000-0000-000000000001'::uuid,
    TRUE,
    'APPROVED'
);

-- 3. IDENTITY RECOVERY TRIGGER
-- If any order exists for "Royal Curry House" that isn't linked to this ID, fix it.
UPDATE public.orders 
SET vendor_id = '11111111-1111-1111-1111-111111111111'::uuid
WHERE vendor_id IN (SELECT id FROM public.vendors WHERE name = 'Royal Curry House' AND id != '11111111-1111-1111-1111-111111111111'::uuid);

-- 4. MASTER BOOTSTRAP RPC (v4 - Optimized)
CREATE OR REPLACE FUNCTION public.get_unified_bootstrap_data(p_user_id TEXT, p_role TEXT)
RETURNS JSON AS $$
DECLARE
    v_profile JSON;
    v_active_orders JSON;
    v_wallet JSON;
    v_vendor_id UUID;
BEGIN
    -- VENDOR BRANCH
    IF p_role = 'vendor' THEN
        -- Robust Lookup: By owner_id OR direct ID
        SELECT id INTO v_vendor_id FROM public.vendors v 
        WHERE v.owner_id::text = p_user_id OR v.id::text = p_user_id 
        ORDER BY (v.owner_id::text = p_user_id) DESC -- Prefer owner match
        LIMIT 1;

        SELECT row_to_json(v) INTO v_profile FROM public.vendors v WHERE v.id = v_vendor_id;
        
        IF v_vendor_id IS NOT NULL THEN
            SELECT json_agg(o) INTO v_active_orders FROM public.order_details_v3 o 
            WHERE o.vendor_id = v_vendor_id 
            AND o.status NOT IN ('delivered', 'cancelled', 'rejected');
        END IF;

    -- CUSTOMER BRANCH
    ELSIF p_role = 'customer' THEN
        SELECT row_to_json(p) INTO v_profile FROM public.customer_profiles p WHERE p.id::text = p_user_id;
        SELECT json_agg(o) INTO v_active_orders FROM public.order_details_v3 o WHERE o.customer_id = p_user_id AND o.status NOT IN ('delivered', 'cancelled', 'rejected');
    
    -- DELIVERY BRANCH
    ELSIF p_role = 'delivery' THEN
        SELECT row_to_json(r) INTO v_profile FROM public.delivery_riders r WHERE r.id::text = p_user_id;
        SELECT json_agg(o) INTO v_active_orders FROM public.order_details_v3 o WHERE o.rider_id::text = p_user_id AND o.status NOT IN ('delivered', 'cancelled', 'rejected');
    END IF;

    -- WALLET FETCH
    SELECT row_to_json(w) INTO v_wallet FROM public.wallets w WHERE w.user_id::text = p_user_id;

    RETURN json_build_object(
        'profile', COALESCE(v_profile, '{}'::json),
        'orders', COALESCE(v_active_orders, '[]'::json),
        'wallet', COALESCE(v_wallet, '{"balance": 0}'::json)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. REAL-TIME BROADCAST WIRING
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

COMMIT;
