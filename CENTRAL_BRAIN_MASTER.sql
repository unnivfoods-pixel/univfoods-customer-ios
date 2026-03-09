-- 🧠 CENTRAL BRAIN MASTER SYSTEM (SINGLE SOURCE OF TRUTH)
-- Implements Point-to-Point Control, Settlement Engine, and Privacy Layers

-- 1. SETTLEMENT & COMMISSION SCHEMA (Point 6)
ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS commission_rate NUMERIC DEFAULT 10.0, -- Default 10%
ADD COLUMN IF NOT EXISTS pending_payout NUMERIC DEFAULT 0;

ALTER TABLE public.delivery_riders
ADD COLUMN IF NOT EXISTS pending_payout NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS base_incentive NUMERIC DEFAULT 0;

ALTER TABLE public.orders
ADD COLUMN IF NOT EXISTS vendor_earning NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS rider_earning NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS platform_earning NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS commission_applied NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS settlement_status TEXT DEFAULT 'PENDING', -- PENDING, SETTLED
ADD COLUMN IF NOT EXISTS address TEXT; -- Added to fix view error

-- 2. AUTOMATED SETTLEMENT ENGINE (Point 6)
CREATE OR REPLACE FUNCTION calculate_order_settlement()
RETURNS TRIGGER AS $$
DECLARE
    v_commission_rate NUMERIC;
    v_delivery_fee NUMERIC := 20.0; -- Default placeholder
    v_item_total NUMERIC;
BEGIN
    -- Only calculate when order is DELIVERED
    IF (NEW.status = 'delivered' AND OLD.status != 'delivered') THEN
        -- Get vendor commission
        SELECT commission_rate INTO v_commission_rate FROM public.vendors WHERE id = NEW.vendor_id;
        
        v_item_total := NEW.total - v_delivery_fee; -- Basic assumption
        NEW.commission_applied := v_commission_rate;
        
        -- Calculations
        NEW.platform_earning := (v_item_total * (v_commission_rate / 100)) + 5.0; -- Commission + Platform Fee
        NEW.vendor_earning := v_item_total - (v_item_total * (v_commission_rate / 100));
        NEW.rider_earning := v_delivery_fee; -- Simplification

        -- Update cumulative pendings
        UPDATE public.vendors SET pending_payout = pending_payout + NEW.vendor_earning WHERE id = NEW.vendor_id;
        UPDATE public.delivery_riders SET pending_payout = pending_payout + NEW.rider_earning WHERE id = NEW.rider_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_order_delivered_settle ON public.orders;
CREATE TRIGGER on_order_delivered_settle
BEFORE UPDATE ON public.orders
FOR EACH ROW EXECUTE PROCEDURE calculate_order_settlement();

-- 3. ADMIN CONTROL & OVERRIDE FUNCTIONS (Point 2, 4)
-- Function to pause vendor instantly
CREATE OR REPLACE FUNCTION admin_toggle_vendor(v_id UUID, is_online BOOLEAN)
RETURNS VOID AS $$
BEGIN
    UPDATE public.vendors SET status = CASE WHEN is_online THEN 'ONLINE' ELSE 'OFFLINE' END WHERE id = v_id;
    
    -- Notify Vendor instantly
    INSERT INTO public.notifications (target_type, vendor_id, title, body, status)
    VALUES ('vendors', v_id, 'Status Update', 'Admin has manually set your status to ' || (CASE WHEN is_online THEN 'ONLINE' ELSE 'OFFLINE' END), 'unread');
END;
$$ LANGUAGE plpgsql;

-- 4. PRIVACY LAYER: MASKED VIEWS (Point 8)
-- View for Vendor: Strip customer phone/full payment
CREATE OR REPLACE VIEW vendor_order_view AS
SELECT 
    o.id, o.vendor_id, o.status, o.items, o.total, o.created_at,
    o.delivery_lat, o.delivery_lng, o.address,
    c.full_name as customer_name -- No phone
FROM public.orders o
JOIN public.customer_profiles c ON o.customer_id = c.id;

-- View for Rider: Strip vendor internal margins
CREATE OR REPLACE VIEW rider_order_view AS
SELECT 
    o.id, o.rider_id, o.status, o.address, o.delivery_lat, o.delivery_lng,
    v.name as vendor_name, v.address as vendor_address, v.location as vendor_location,
    c.full_name as customer_name, c.phone as customer_phone -- Needed for delivery
FROM public.orders o
JOIN public.vendors v ON o.vendor_id = v.id
JOIN public.customer_profiles c ON o.customer_id = c.id;

-- 5. REALTIME EVENT BRIDGE (Point 10)
-- Comprehensive notification router
CREATE OR REPLACE FUNCTION order_event_router()
RETURNS TRIGGER AS $$
BEGIN
    -- Customer Notification
    INSERT INTO public.notifications (user_id, title, body, data)
    VALUES (
        NEW.customer_id, 
        'Order Update: ' || UPPER(NEW.status), 
        'Your order from ' || (SELECT name FROM vendors WHERE id = NEW.vendor_id) || ' is now ' || NEW.status,
        jsonb_build_object('order_id', NEW.id, 'type', 'status_change')
    );

    -- Special event: Ready for Pickup -> Trigger Rider Search logic (Point 3)
    IF (NEW.status = 'ready' AND OLD.status != 'ready') THEN
         -- Log for Admin to see "Rider Search"
         INSERT INTO public.fraud_logs (order_id, reason, severity)
         VALUES (NEW.id, 'SYSTEM: Automated Rider Search Started', 'LOW');
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_order_event ON public.orders;
CREATE TRIGGER on_order_event
AFTER UPDATE ON public.orders
FOR EACH ROW EXECUTE PROCEDURE order_event_router();

-- 6. FRAUD & CONTROL MONITORING (Point 11)
ALTER TABLE public.customer_profiles 
ADD COLUMN IF NOT EXISTS cod_mismatch_count INTEGER DEFAULT 0;

CREATE OR REPLACE FUNCTION log_cod_mismatch(o_id UUID, r_id UUID)
RETURNS VOID AS $$
BEGIN
    INSERT INTO public.fraud_logs (order_id, customer_id, reason, severity, action_taken)
    SELECT id, customer_id, 'COD Cash Mismatch detected by Rider', 'HIGH', 'Flagged for Admin'
    FROM public.orders WHERE id = o_id;
    
    UPDATE public.customer_profiles SET cod_mismatch_count = cod_mismatch_count + 1
    WHERE id = (SELECT customer_id FROM public.orders WHERE id = o_id);
END;
$$ LANGUAGE plpgsql;
