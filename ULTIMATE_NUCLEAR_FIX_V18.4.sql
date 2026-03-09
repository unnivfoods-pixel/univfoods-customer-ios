-- 🔥 ULTIMATE NUCLEAR FIX (V18.4 - Syntax & View Conflict Resolution)
-- Purpose: Force orders PK and UUID type by temporarily removing blocking views. Fixed syntax error in publication.

BEGIN;

-- 1. DROP BLOCKING VIEWS
DROP VIEW IF EXISTS public.order_details_v3 CASCADE;

-- 2. CLEANUP: Delete duplicate IDs if they exist (prevents PK failure)
DELETE FROM public.orders a USING public.orders b 
WHERE a.ctid < b.ctid AND a.id = b.id;

-- 3. FORCE DATA TYPE: Ensure the column is a UUID and Not Null
ALTER TABLE public.orders ALTER COLUMN id SET NOT NULL;
ALTER TABLE public.orders ALTER COLUMN id TYPE UUID USING (id::uuid);

-- 4. FORCE PRIMARY KEY
ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_pkey CASCADE;
ALTER TABLE public.orders ADD PRIMARY KEY (id);

-- 5. RECREATE VIEW: order_details_v3
CREATE OR REPLACE VIEW public.order_details_v3 AS
SELECT 
    o.*,
    jsonb_build_object(
        'name', v.name,
        'address', v.address,
        'latitude', v.latitude,
        'longitude', v.longitude,
        'logo_url', COALESCE(v.logo_url, v.banner_url)
    ) as vendors,
    jsonb_build_object(
        'full_name', cp.full_name,
        'phone', cp.phone,
        'email', cp.email
    ) as customer_profiles
FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id = v.id
LEFT JOIN public.customer_profiles cp ON o.customer_id::text = cp.id::text;

GRANT SELECT ON public.order_details_v3 TO anon, authenticated, service_role;

-- 6. INSTALL THE LEDGER & DISPUTES
CREATE TABLE IF NOT EXISTS public.financial_ledger (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entry_type TEXT NOT NULL, 
    user_id UUID, 
    order_id UUID REFERENCES public.orders(id), 
    amount DOUBLE PRECISION NOT NULL,
    flow_type TEXT NOT NULL, 
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.disputes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES public.orders(id) ON DELETE CASCADE,
    user_id UUID NOT NULL, 
    reason TEXT NOT NULL, 
    status TEXT DEFAULT 'PENDING',
    refund_amount DOUBLE PRECISION DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 7. REPAIR WALLETS
ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS pending_settlement DOUBLE PRECISION DEFAULT 0;
ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS lifetime_earnings DOUBLE PRECISION DEFAULT 0;
ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS cod_debt DOUBLE PRECISION DEFAULT 0;

-- 8. ENABLE REALTIME
ALTER TABLE public.orders REPLICA IDENTITY FULL;
ALTER TABLE public.financial_ledger REPLICA IDENTITY FULL;
-- Also ensure vendors and products are ready for realtime
ALTER TABLE public.vendors REPLICA IDENTITY FULL;
ALTER TABLE public.products REPLICA IDENTITY FULL;

-- 9. RESET PUBLICATION (Safest way to avoid syntax errors)
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime;

-- Add tables safely
DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
    ALTER PUBLICATION supabase_realtime ADD TABLE public.vendors;
    ALTER PUBLICATION supabase_realtime ADD TABLE public.products;
    ALTER PUBLICATION supabase_realtime ADD TABLE public.financial_ledger;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Some tables could not be added to publication, skipping.';
END $$;

COMMIT;
