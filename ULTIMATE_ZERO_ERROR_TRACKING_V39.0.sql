-- 🌌 MISSION CONTROL V39.0 - THE TACTICAL SYNC
-- 🎯 GOAL: Ensure real-time state consistency across Rider/Vendor/Customer.
-- 🛠️ CLINICAL REPAIR:
--    1. Automatic Mission Clearance: Clear rider's active_order_id when order is cancelled/finished.
--    2. Bootstrap Precision: Stop showing cancelled missions in the Rider Radar.
--    3. Real-time Pub-Sub Re-arming.

BEGIN;

-- 1. TACTICAL TRIGGER: Auto-manage Rider Active Order State
CREATE OR REPLACE FUNCTION public.sync_rider_mission_state()
RETURNS TRIGGER AS $$
BEGIN
    -- If order reaches terminal state, clear the rider's active_order_id
    IF NEW.status IN ('CANCELLED', 'DELIVERED', 'REJECTED', 'COMPLETED') THEN
        UPDATE public.delivery_riders 
        SET active_order_id = NULL 
        WHERE active_order_id = NEW.id;
    END IF;
    
    -- If rider is newly assigned, update their profile
    IF (OLD.rider_id IS NULL AND NEW.rider_id IS NOT NULL) OR (OLD.rider_id != NEW.rider_id) THEN
        UPDATE public.delivery_riders 
        SET active_order_id = NEW.id 
        WHERE id = NEW.rider_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_sync_rider_mission ON public.orders;
CREATE TRIGGER trg_sync_rider_mission
AFTER UPDATE ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.sync_rider_mission_state();

-- 2. BOOTSTRAP UPGRADE V39.1 (The "Ghost Order" Exorcism)
CREATE OR REPLACE FUNCTION public.get_unified_bootstrap_data(p_user_id TEXT, p_role TEXT DEFAULT 'customer')
RETURNS JSONB AS $$
DECLARE
    v_profile JSONB;
    v_orders JSONB;
    v_wallet JSONB;
    v_vendor_ids UUID[];
BEGIN
    -- Profile Resolution
    IF p_role = 'customer' THEN
        SELECT row_to_json(p)::jsonb INTO v_profile FROM public.customer_profiles p WHERE id::TEXT = p_user_id;
    ELSIF p_role = 'vendor' THEN
        SELECT array_agg(id) INTO v_vendor_ids FROM public.vendors WHERE owner_id::TEXT = p_user_id;
        SELECT row_to_json(v)::jsonb INTO v_profile FROM public.vendors WHERE id = ANY(v_vendor_ids) LIMIT 1;
    ELSIF p_role = 'delivery' THEN
        SELECT row_to_json(r)::jsonb INTO v_profile FROM public.delivery_riders r WHERE id::TEXT = p_user_id;
    END IF;

    -- Wallet
    SELECT row_to_json(w)::jsonb INTO v_wallet FROM public.wallets w WHERE user_id::TEXT = p_user_id;

    -- 📦 MASTER ORDER AGGREGATION (With State Filtering)
    SELECT json_agg(o)::jsonb INTO v_orders 
    FROM (
        SELECT * FROM public.order_details_v3 
        WHERE (
            -- Customers see all 50 recent
            (p_role = 'customer' AND customer_id::TEXT = p_user_id)
            OR
            -- Vendors see all relevant to their ID or Ownership
            (p_role = 'vendor' AND (vendor_id::TEXT = ANY(v_vendor_ids::TEXT[]) OR vendor_owner_id::TEXT = p_user_id))
            OR
            -- Delivery Riders: ONLY see active missions (Assigned to them OR Searchable)
            (p_role = 'delivery' AND 
                status NOT IN ('DELIVERED', 'CANCELLED', 'REJECTED', 'COMPLETED') AND
                (rider_id::TEXT = p_user_id OR rider_id IS NULL)
            )
        )
        ORDER BY created_at DESC 
        LIMIT 50
    ) o;

    RETURN jsonb_build_object(
        'profile', COALESCE(v_profile, '{}'::jsonb),
        'orders', COALESCE(v_orders, '[]'::jsonb),
        'wallet', COALESCE(v_wallet, '{"balance": 0}'::jsonb),
        'timestamp', NOW()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. BROADCAST CHANNEL ARMED (All Tables)
ALTER TABLE public.orders REPLICA IDENTITY FULL;
ALTER TABLE public.delivery_riders REPLICA IDENTITY FULL;
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

COMMIT;
NOTIFY pgrst, 'reload schema';
