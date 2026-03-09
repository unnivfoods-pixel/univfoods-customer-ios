-- 🛰️ LOGISTICS RECOVERY & INSTRUCTION NODE (V7.2)
-- Fixes missing action nodes for Instructions and Support.

BEGIN;

-- 1. INSTRUCTION MASTER FUNCTION
-- Allows customers to update delivery instructions in realtime.
CREATE OR REPLACE FUNCTION public.update_order_instructions_v3(
    p_order_id TEXT,
    p_instructions TEXT
)
RETURNS VOID AS $$
BEGIN
    UPDATE public.orders 
    SET delivery_instructions = p_instructions 
    WHERE id::text = p_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. AUTOMATIC SUPPORT TICKET GENERATOR
-- Creates or returns an active support ticket for an order.
CREATE OR REPLACE FUNCTION public.get_or_create_order_support_v3(
    p_order_id TEXT,
    p_user_id TEXT
)
RETURNS TEXT AS $$
DECLARE
    v_ticket_id TEXT;
BEGIN
    -- Check for existing open ticket for this order
    SELECT id::text INTO v_ticket_id 
    FROM public.support_tickets 
    WHERE order_id::text = p_order_id AND status != 'closed'
    LIMIT 1;

    IF v_ticket_id IS NULL THEN
        INSERT INTO public.support_tickets (user_id, order_id, subject, status, priority)
        VALUES (p_user_id::uuid, p_order_id::uuid, 'Order Support: ' || SUBSTRING(p_order_id, 1, 8), 'open', 'high')
        RETURNING id::text INTO v_ticket_id;
    END IF;

    RETURN v_ticket_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.update_order_instructions_v3 TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_or_create_order_support_v3 TO anon, authenticated;

COMMIT;

NOTIFY pgrst, 'reload schema';
