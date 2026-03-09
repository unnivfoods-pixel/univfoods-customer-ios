-- 🛰️ RIDER INTELLIGENCE & TIP UPGRADE (V7.1)
-- Enhances Rider profiles and adds Tipping + Instructions logic.

BEGIN;

-- 1. ENHANCE RIDER PROFILES
ALTER TABLE public.delivery_riders ADD COLUMN IF NOT EXISTS rating DOUBLE PRECISION DEFAULT 4.8;
ALTER TABLE public.delivery_riders ADD COLUMN IF NOT EXISTS missions_completed INTEGER DEFAULT 120;
ALTER TABLE public.delivery_riders ADD COLUMN IF NOT EXISTS phone TEXT;

-- 2. ENHANCE ORDERS FOR RIDER CONTEXT
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS tip_amount DOUBLE PRECISION DEFAULT 0;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_instructions TEXT;

-- 3. TIP MASTER FUNCTION
-- Atomically updates order tip and (optionally) transfers from wallet if needed.
-- For now, just recording the tip in the order.
CREATE OR REPLACE FUNCTION public.add_order_tip_v3(
    p_order_id TEXT,
    p_amount DOUBLE PRECISION
)
RETURNS VOID AS $$
BEGIN
    UPDATE public.orders 
    SET tip_amount = tip_amount + p_amount 
    WHERE id::text = p_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.add_order_tip_v3 TO anon, authenticated;

COMMIT;

NOTIFY pgrst, 'reload schema';
