-- 🌌 ULTIMATE PRODUCTION CLEANUP V44.0
-- 🎯 MISSION: Scrub all remaining Demo artifacts.

BEGIN;

-- 1. Remove Simulation Overloads
DROP FUNCTION IF EXISTS public.verify_order_otp(UUID, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.verify_order_otp_v1(UUID, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.verify_order_otp_v2(UUID, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.verify_order_otp_v3(UUID, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.verify_order_otp_v4(UUID, TEXT, TEXT);

-- 2. SANITIZE EXISTING DATA (Prevent constraint violation)
UPDATE public.orders SET status = 'PLACED' WHERE status IS NULL;
UPDATE public.orders SET status = UPPER(status);
UPDATE public.orders SET payment_status = 'PENDING' WHERE payment_status IS NULL;
UPDATE public.orders SET payment_status = UPPER(payment_status);

-- Standardize Status check constraint (Production Grade)
ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_status_check;
ALTER TABLE public.orders ADD CONSTRAINT orders_status_check 
CHECK (status IN (
    'PAYMENT_PENDING',
    'PLACED',
    'ACCEPTED',
    'PREPARING',
    'READY_FOR_PICKUP',
    'RIDER_ASSIGNED',
    'PICKED_UP',
    'ON_THE_WAY',
    'DELIVERED',
    'CANCELLED',
    'REFUNDED'
));

-- 3. Standardize Payment check constraint
ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_payment_status_check;
ALTER TABLE public.orders ADD CONSTRAINT orders_payment_status_check 
CHECK (payment_status IN ('PENDING', 'PAID', 'REFUNDED', 'FAILED'));

-- 4. Re-confirm Manish's Shop Connectivity
UPDATE public.vendors 
SET id = 'c1589737-0561-4d9d-a499-214655f16992',
    owner_id = '35e786fa-e0cc-48d6-b3ee-6a4250679474' 
WHERE name ILIKE '%Royal Curry House%';

COMMIT;
NOTIFY pgrst, 'reload schema';
