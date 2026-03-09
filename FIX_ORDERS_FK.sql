-- ==========================================
-- FIX ORDERS FOREIGN KEY (WITH VIEW HANDLING)
-- ==========================================

BEGIN;

-- 1. DROP DEPENDENT VIEWS (Must be done to alter column type)
DROP VIEW IF EXISTS public.vendor_order_view;
DROP VIEW IF EXISTS public.rider_order_view;

-- 2. ALTER COLUMN TYPE
-- Now we can safely change the type to TEXT
ALTER TABLE public.orders ALTER COLUMN customer_id TYPE TEXT;

-- 3. RECREATE FOREIGN KEY
ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_customer_id_fkey;
ALTER TABLE public.orders 
  ADD CONSTRAINT orders_customer_id_fkey 
  FOREIGN KEY (customer_id) 
  REFERENCES public.customer_profiles(id)
  ON UPDATE CASCADE
  ON DELETE SET NULL;

-- 4. RECREATE VIEWS (Restoring functionality)

-- Vendor View: Strip customer phone/full payment
CREATE OR REPLACE VIEW public.vendor_order_view AS
SELECT 
    o.id, 
    o.vendor_id, 
    o.status, 
    o.items, 
    o.total, 
    o.created_at,
    o.delivery_lat, 
    o.delivery_lng, 
    o.address,
    c.full_name as customer_name
FROM public.orders o
JOIN public.customer_profiles c ON o.customer_id = c.id;

-- Rider View: Strip vendor internal margins
CREATE OR REPLACE VIEW public.rider_order_view AS
SELECT 
    o.id, 
    o.rider_id, 
    o.status, 
    o.address, 
    o.delivery_lat, 
    o.delivery_lng,
    v.name as vendor_name, 
    v.address as vendor_address, 
    NULL as vendor_location, -- Placeholder or fix if column exists
    c.full_name as customer_name, 
    c.phone as customer_phone
FROM public.orders o
JOIN public.vendors v ON o.vendor_id = v.id
JOIN public.customer_profiles c ON o.customer_id = c.id;

-- 5. ENSURE REALTIME
ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;

COMMIT;
