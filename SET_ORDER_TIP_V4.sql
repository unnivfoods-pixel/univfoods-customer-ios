-- 🖋️ UPDATE TIPPING LOGIC (V4)
-- Changes tipping from additive to SET-based, allowing for toggling/removal.

BEGIN;

CREATE OR REPLACE FUNCTION public.set_order_tip_v4(
    p_order_id TEXT,
    p_amount DOUBLE PRECISION
)
RETURNS VOID AS $$
BEGIN
    UPDATE public.orders 
    SET tip_amount = p_amount 
    WHERE id::text = p_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.set_order_tip_v4 TO anon, authenticated;

COMMIT;

NOTIFY pgrst, 'reload schema';
