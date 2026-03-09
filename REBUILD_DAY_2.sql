-- ==========================================================
-- DAY 2: CLEAN ORDER STRUCTURE (SINGLE SOURCE OF TRUTH)
-- Goal: One clean orders table. Backend controls everything.
-- ==========================================================

BEGIN;

-- 1. ENSURE ALL REQUIRED COLUMNS EXIST
DO $$
BEGIN
  -- Core IDs
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='customer_id') THEN ALTER TABLE orders ADD COLUMN customer_id TEXT; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='vendor_id') THEN ALTER TABLE orders ADD COLUMN vendor_id TEXT; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='delivery_id') THEN ALTER TABLE orders ADD COLUMN delivery_id TEXT; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='rider_id') THEN ALTER TABLE orders ADD COLUMN rider_id TEXT; END IF;

  -- Coordinates
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='delivery_lat') THEN ALTER TABLE orders ADD COLUMN delivery_lat NUMERIC; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='delivery_lng') THEN ALTER TABLE orders ADD COLUMN delivery_lng NUMERIC; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='vendor_lat') THEN ALTER TABLE orders ADD COLUMN vendor_lat NUMERIC; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='vendor_lng') THEN ALTER TABLE orders ADD COLUMN vendor_lng NUMERIC; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='rider_lat') THEN ALTER TABLE orders ADD COLUMN rider_lat NUMERIC; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='rider_lng') THEN ALTER TABLE orders ADD COLUMN rider_lng NUMERIC; END IF;

  -- Status & Financials
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='order_status') THEN ALTER TABLE orders ADD COLUMN order_status TEXT DEFAULT 'PLACED'; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='payment_status') THEN ALTER TABLE orders ADD COLUMN payment_status TEXT DEFAULT 'PENDING'; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='total_amount') THEN ALTER TABLE orders ADD COLUMN total_amount NUMERIC DEFAULT 0; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='is_settled') THEN ALTER TABLE orders ADD COLUMN is_settled BOOLEAN DEFAULT FALSE; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='vendor_earning') THEN ALTER TABLE orders ADD COLUMN vendor_earning NUMERIC DEFAULT 0; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='delivery_fee') THEN ALTER TABLE orders ADD COLUMN delivery_fee NUMERIC DEFAULT 0; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='commission_rate') THEN ALTER TABLE orders ADD COLUMN commission_rate NUMERIC DEFAULT 15; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='rejection_reason') THEN ALTER TABLE orders ADD COLUMN rejection_reason TEXT; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='cancellation_reason') THEN ALTER TABLE orders ADD COLUMN cancellation_reason TEXT; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='settlement_status') THEN ALTER TABLE orders ADD COLUMN settlement_status TEXT DEFAULT 'PENDING'; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='updated_at') THEN ALTER TABLE orders ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW(); END IF;
END $$;

-- 2. BACKEND-CONTROLLED ORDER PLACEMENT RPC
-- Frontend sends params. Backend inserts with forced status. No frontend can set order_status.
CREATE OR REPLACE FUNCTION public.place_order_v1(p_params JSONB)
RETURNS JSONB AS $$
DECLARE
  v_order_id UUID;
  v_customer_id TEXT;
  v_vendor_id TEXT;
  v_vendor_lat NUMERIC;
  v_vendor_lng NUMERIC;
  v_payment_method TEXT;
BEGIN
  v_customer_id   := COALESCE(p_params->>'customer_id', auth.uid()::text);
  v_vendor_id     := p_params->>'vendor_id';
  v_payment_method := COALESCE(p_params->>'payment_method', 'COD');

  IF v_customer_id IS NULL THEN
    RAISE EXCEPTION 'Customer ID is required';
  END IF;
  IF v_vendor_id IS NULL THEN
    RAISE EXCEPTION 'Vendor ID is required';
  END IF;

  -- Fetch vendor coordinates from DB (not from frontend)
  SELECT COALESCE(latitude, lat), COALESCE(longitude, lng)
  INTO v_vendor_lat, v_vendor_lng
  FROM public.vendors WHERE id::text = v_vendor_id LIMIT 1;

  INSERT INTO public.orders (
    customer_id, vendor_id,
    delivery_lat, delivery_lng,
    vendor_lat, vendor_lng,
    order_status,    -- BACKEND CONTROLLED
    payment_status,  -- BACKEND CONTROLLED
    total_amount,
    total,
    delivery_address,
    payment_method,
    items,
    created_at, updated_at
  ) VALUES (
    v_customer_id, v_vendor_id,
    (p_params->>'lat')::NUMERIC,    (p_params->>'lng')::NUMERIC,
    v_vendor_lat,                   v_vendor_lng,
    CASE WHEN v_payment_method = 'COD' THEN 'PLACED' ELSE 'PAYMENT_PENDING' END,
    CASE WHEN v_payment_method = 'COD' THEN 'COD_PENDING' ELSE 'PENDING' END,
    (p_params->>'total')::NUMERIC,
    (p_params->>'total')::NUMERIC,
    p_params->>'address',
    v_payment_method,
    p_params->'items',
    NOW(), NOW()
  ) RETURNING id INTO v_order_id;

  RETURN jsonb_build_object('success', true, 'order_id', v_order_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. IDENTITY SAFETY TRIGGER
-- Only stamps customer_id from auth.uid() if available (Supabase Auth).
-- Allows Firebase UID passthrough from the RPC above.
CREATE OR REPLACE FUNCTION public.secure_order_identity()
RETURNS TRIGGER AS $$
BEGIN
  IF auth.uid() IS NOT NULL THEN
    NEW.customer_id := auth.uid()::text;
  END IF;
  IF NEW.customer_id IS NULL THEN
    RAISE EXCEPTION 'customer_id is required';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_secure_order_identity ON public.orders;
CREATE TRIGGER tr_secure_order_identity
BEFORE INSERT ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.secure_order_identity();

COMMIT;
NOTIFY pgrst, 'reload schema';
