-- ==========================================================
-- DAY 5: REAL GPS TRACKING ENGINE
-- Goal: Remove demo coordinates. DB-driven tracking only.
-- ==========================================================

BEGIN;

-- 1. ENSURE TRACKING COLUMNS EXIST ON ORDERS
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='rider_lat') THEN ALTER TABLE orders ADD COLUMN rider_lat NUMERIC; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='rider_lng') THEN ALTER TABLE orders ADD COLUMN rider_lng NUMERIC; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='rider_last_seen') THEN ALTER TABLE orders ADD COLUMN rider_last_seen TIMESTAMPTZ; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='eta_minutes') THEN ALTER TABLE orders ADD COLUMN eta_minutes INTEGER DEFAULT 0; END IF;
END $$;

-- 2. LIVE TRACKING TABLE (Dedicated for frequent GPS writes)
CREATE TABLE IF NOT EXISTS public.order_live_tracking (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id     TEXT        NOT NULL UNIQUE,
  rider_id     TEXT        NOT NULL,
  lat          NUMERIC     NOT NULL,
  lng          NUMERIC     NOT NULL,
  speed        NUMERIC     DEFAULT 0,
  heading      NUMERIC     DEFAULT 0,
  eta_minutes  INTEGER     DEFAULT 0,
  updated_at   TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.order_live_tracking ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "RLS_LiveTracking_V1" ON public.order_live_tracking;
CREATE POLICY "RLS_LiveTracking_V1" ON public.order_live_tracking
FOR ALL USING (
  is_admin_strict() OR
  rider_id = auth.uid()::text OR
  rider_id = (current_setting('request.jwt.claims', true)::json->>'sub') OR
  EXISTS (
    SELECT 1 FROM public.orders
    WHERE orders.id::text = order_live_tracking.order_id
    AND (orders.customer_id = auth.uid()::text OR orders.vendor_id = auth.uid()::text)
  )
);

ALTER TABLE public.order_live_tracking REPLICA IDENTITY FULL;

DO $$
DECLARE v_all BOOLEAN;
BEGIN
  SELECT puballtables INTO v_all FROM pg_publication WHERE pubname = 'supabase_realtime';
  IF v_all IS NOT TRUE THEN
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.order_live_tracking; EXCEPTION WHEN duplicate_object THEN NULL; END;
  END IF;
END $$;

-- 3. RIDER LOCATION UPDATE RPC (Called every 5 seconds from Delivery App)
-- Writes to BOTH the live_tracking table AND the orders row (for subscription triggers)
CREATE OR REPLACE FUNCTION public.update_rider_location_v1(
  p_order_id  TEXT,
  p_rider_id  TEXT,
  p_lat       NUMERIC,
  p_lng       NUMERIC,
  p_speed     NUMERIC DEFAULT 0,
  p_heading   NUMERIC DEFAULT 0,
  p_eta       INTEGER DEFAULT 0
)
RETURNS JSONB AS $$
BEGIN
  -- Upsert into live tracking table
  INSERT INTO public.order_live_tracking (order_id, rider_id, lat, lng, speed, heading, eta_minutes, updated_at)
  VALUES (p_order_id, p_rider_id, p_lat, p_lng, p_speed, p_heading, p_eta, NOW())
  ON CONFLICT (order_id) DO UPDATE SET
    lat         = EXCLUDED.lat,
    lng         = EXCLUDED.lng,
    speed       = EXCLUDED.speed,
    heading     = EXCLUDED.heading,
    eta_minutes = EXCLUDED.eta_minutes,
    updated_at  = NOW();

  -- Also update orders row to trigger Realtime subscription for Customer App
  UPDATE public.orders SET
    rider_lat      = p_lat,
    rider_lng      = p_lng,
    rider_last_seen = NOW(),
    eta_minutes    = p_eta,
    updated_at     = NOW()
  WHERE id::text = p_order_id;

  RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
NOTIFY pgrst, 'reload schema';
