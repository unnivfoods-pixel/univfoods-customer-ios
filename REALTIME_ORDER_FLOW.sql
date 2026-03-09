-- =============================================================================
-- REALTIME ORDER FLOW & DELIVERY ASSIGNMENT LOGIC
-- =============================================================================

-- 1. Create a function to auto-assign delivery partner or notify them
-- This function runs when an order is marked 'ready' (or 'preparing' depending on logic)
CREATE OR REPLACE FUNCTION public.handle_order_status_change()
RETURNS TRIGGER AS $$
BEGIN
    -- WHEN ORDER IS MARKED 'READY' -> FIND NEAREST DRIVER
    IF NEW.status = 'ready' AND OLD.status != 'ready' THEN
        -- Logic to notify drivers would typically be here (via Edge Function)
        -- For now, we update the order to 'searching_for_partner' if not assigned
        IF NEW.delivery_partner_id IS NULL THEN
             UPDATE public.orders 
             SET status = 'searching_for_partner' 
             WHERE id = NEW.id;
        END IF;
    END IF;

    -- WHEN ORDER IS ACCEPTED BY VENDOR ('preparing') -> NOTIFY USER
    -- (This is handled by the client-side subscription, but we can log it)

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. Trigger for Order Status
DROP TRIGGER IF EXISTS on_order_status_change ON public.orders;
CREATE TRIGGER on_order_status_change
AFTER UPDATE OF status ON public.orders
FOR EACH ROW
EXECUTE FUNCTION public.handle_order_status_change();

-- 3. Policy for Delivery Riders to see available orders
-- Riders should see orders that are 'ready' or 'searching_for_partner' in their zone?
-- Simpler: Riders can see ALL orders where delivery_partner_id is NULL and status is relevant.

DROP POLICY IF EXISTS "Riders see unassigned orders" ON public.orders;
CREATE POLICY "Riders see unassigned orders"
ON public.orders FOR SELECT
USING (
    (status = 'ready' OR status = 'searching_for_partner') 
    AND delivery_partner_id IS NULL
);

-- 4. Policy for Riders to ACCEPT an order
-- A rider can update the order to claim it: Set delivery_partner_id = NEW.id and status = 'out_for_delivery' (or 'pickup_pending')
DROP POLICY IF EXISTS "Riders claim orders" ON public.orders;
CREATE POLICY "Riders claim orders"
ON public.orders FOR UPDATE
USING (
    (status = 'ready' OR status = 'searching_for_partner')
    AND delivery_partner_id IS NULL
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.delivery_riders 
        WHERE id = delivery_partner_id 
        AND user_id = auth.uid()
    )
);

-- 5. Enable Realtime for EVERYTHING
ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
ALTER PUBLICATION supabase_realtime ADD TABLE public.order_items;
ALTER PUBLICATION supabase_realtime ADD TABLE public.delivery_riders;

