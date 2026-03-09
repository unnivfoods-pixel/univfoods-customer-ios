-- ==========================================================
-- DAY 4: REALTIME SUBSCRIPTION ENGINE
-- Goal: All roles get instant updates. No refresh button.
-- ==========================================================

BEGIN;

-- 1. ENABLE FULL REPLICA IDENTITY (Required for Realtime change payload)
ALTER TABLE public.orders         REPLICA IDENTITY FULL;
ALTER TABLE public.wallets        REPLICA IDENTITY FULL;
ALTER TABLE public.notifications  REPLICA IDENTITY FULL;
ALTER TABLE public.vendors        REPLICA IDENTITY FULL;

-- 2. ADD TO REALTIME PUBLICATION (Robust — skips if already ALL TABLES)
DO $$
DECLARE
  v_is_all_tables BOOLEAN;
BEGIN
  SELECT puballtables INTO v_is_all_tables
  FROM pg_publication WHERE pubname = 'supabase_realtime';

  IF v_is_all_tables IS NOT TRUE THEN
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;        EXCEPTION WHEN duplicate_object THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.wallets;       EXCEPTION WHEN duplicate_object THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications; EXCEPTION WHEN duplicate_object THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.vendors;       EXCEPTION WHEN duplicate_object THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.payments;      EXCEPTION WHEN duplicate_object THEN NULL; END;
  END IF;
END $$;

-- 3. UNIFIED ORDER VIEW (What all apps subscribe to)
-- Drop first to allow column changes
DROP VIEW IF EXISTS public.order_tracking_v1 CASCADE;
CREATE VIEW public.order_tracking_v1 AS
SELECT
  o.id,
  o.id AS order_id,
  o.customer_id,
  o.vendor_id,
  o.rider_id,
  o.delivery_id,
  o.order_status,
  o.payment_status,
  o.payment_method,
  COALESCE(o.total_amount, o.total, 0) AS total_amount,
  o.delivery_lat,
  o.delivery_lng,
  o.vendor_lat,
  o.vendor_lng,
  o.rider_lat,
  o.rider_lng,
  o.items,
  o.delivery_address,
  o.rejection_reason,
  o.cancellation_reason,
  o.is_settled,
  o.vendor_earning,
  o.created_at,
  o.updated_at,
  -- Vendor info
  COALESCE(v.shop_name, v.name, 'Unknown Vendor')  AS vendor_name,
  COALESCE(v.image_url, v.logo_url, '')            AS vendor_image,
  v.phone                                           AS vendor_phone,
  v.address                                         AS vendor_address
FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id::text = v.id::text;

GRANT SELECT ON public.order_tracking_v1 TO anon, authenticated, service_role;

-- 4. BOOTSTRAP DATA RPC (Called once on app startup — replaces multiple fetches)
CREATE OR REPLACE FUNCTION public.get_user_bootstrap(p_user_id TEXT, p_role TEXT DEFAULT 'customer')
RETURNS JSONB AS $$
DECLARE
  v_profile JSONB;
  v_orders  JSONB;
  v_wallet  JSONB;
  v_vendor_id TEXT;
BEGIN
  -- Resolve vendor UUID from owner_id (Firebase UID)
  IF p_role = 'vendor' THEN
    SELECT id::text INTO v_vendor_id FROM public.vendors WHERE owner_id::text = p_user_id LIMIT 1;
  END IF;

  -- Profile
  IF p_role = 'customer' THEN
    SELECT row_to_json(p)::jsonb INTO v_profile FROM public.customer_profiles p WHERE id = p_user_id;
  ELSIF p_role = 'vendor' THEN
    SELECT row_to_json(v)::jsonb INTO v_profile FROM public.vendors v WHERE owner_id::text = p_user_id LIMIT 1;
  ELSIF p_role IN ('delivery', 'rider') THEN
    SELECT row_to_json(r)::jsonb INTO v_profile FROM public.delivery_riders r WHERE id::text = p_user_id LIMIT 1;
  END IF;

  -- Orders (role-filtered)
  SELECT json_agg(o ORDER BY o.created_at DESC)::jsonb INTO v_orders
  FROM public.order_tracking_v1 o
  WHERE
    (p_role = 'customer'            AND o.customer_id = p_user_id) OR
    (p_role = 'vendor'              AND (o.vendor_id = p_user_id OR o.vendor_id = v_vendor_id)) OR
    (p_role IN ('delivery','rider') AND (o.rider_id = p_user_id OR o.delivery_id = p_user_id));

  -- Wallet
  SELECT row_to_json(w)::jsonb INTO v_wallet
  FROM public.wallets w WHERE user_id = p_user_id;

  RETURN jsonb_build_object(
    'profile', COALESCE(v_profile, '{}'::jsonb),
    'orders',  COALESCE(v_orders,  '[]'::jsonb),
    'wallet',  COALESCE(v_wallet,  '{"balance":0}'::jsonb),
    'ts',      NOW()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
NOTIFY pgrst, 'reload schema';
