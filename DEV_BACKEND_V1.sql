-- 🧪 DEVELOPMENT BACKEND FOR VENDOR & DELIVERY APPS
-- This script adds new, versioned RPCs for Vendor and Delivery apps.
-- 🔒 CRITICAL: CUSTOMER APIS are NOT modified here.

-- 1. 📂 VENDOR DASHBOARD RPC (Unified fetch for better performance)
CREATE OR REPLACE FUNCTION get_vendor_dashboard_v1(p_vendor_auth_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_vendor_id UUID;
    v_orders JSONB;
    v_stats JSONB;
    v_profile JSONB;
BEGIN
    -- Resolve vendor_id from auth_id
    SELECT id INTO v_vendor_id FROM vendors WHERE auth_id = p_vendor_auth_id LIMIT 1;
    
    IF v_vendor_id IS NULL THEN
        RETURN jsonb_build_object('error', 'Vendor not found');
    END IF;

    -- Get Recent Orders (Limit 50 for performance)
    SELECT jsonb_agg(o) INTO v_orders FROM (
        SELECT id, customer_id, items, total, status, created_at, customer_phone, delivery_address, rejection_reason
        FROM orders 
        WHERE vendor_id = v_vendor_id 
        ORDER BY created_at DESC 
        LIMIT 50
    ) o;

    -- Get Stats
    SELECT jsonb_build_object(
        'total_earnings', COALESCE(SUM(total), 0),
        'total_orders', COUNT(*),
        'pending_orders', COUNT(*) FILTER (WHERE status = 'PLACED'),
        'active_orders', COUNT(*) FILTER (WHERE status IN ('ACCEPTED', 'PREPARING', 'READY_FOR_PICKUP', 'PICKED_UP', 'ON_THE_WAY'))
    ) INTO v_stats
    FROM orders 
    WHERE vendor_id = v_vendor_id;

    -- Get Profile
    SELECT jsonb_build_object(
        'name', name,
        'status', status,
        'is_open', is_open,
        'email', email,
        'phone', phone
    ) INTO v_profile
    FROM vendors
    WHERE id = v_vendor_id;

    RETURN jsonb_build_object(
        'vendor_id', v_vendor_id,
        'orders', COALESCE(v_orders, '[]'::jsonb),
        'stats', v_stats,
        'profile', v_profile
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2.1 🛵 RIDER DASHBOARD RPC
CREATE OR REPLACE FUNCTION get_rider_dashboard_v1(p_rider_auth_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_rider_id UUID;
    v_active_orders JSONB;
    v_available_orders JSONB;
    v_stats JSONB;
BEGIN
    SELECT id INTO v_rider_id FROM delivery_riders WHERE auth_id = p_rider_auth_id LIMIT 1;
    
    IF v_rider_id IS NULL THEN
        RETURN jsonb_build_object('error', 'Rider not found');
    END IF;

    -- My Active Orders
    SELECT jsonb_agg(o) INTO v_active_orders FROM (
        SELECT id, customer_id, vendor_id, items, total, status, delivery_address, delivery_lat, delivery_lng
        FROM orders 
        WHERE rider_id = v_rider_id AND status NOT IN ('DELIVERED', 'CANCELLED', 'REJECTED')
    ) o;

    -- Available Orders (in radius if logic exists, for now just PLACED or READY)
    -- This would normally have distance logic, but keeping it simple for dev
    SELECT jsonb_agg(o) INTO v_available_orders FROM (
        SELECT id, vendor_id, total, status, delivery_address
        FROM orders 
        WHERE status = 'READY_FOR_PICKUP' AND rider_id IS NULL
        LIMIT 20
    ) o;

    -- Stats
    SELECT jsonb_build_object(
        'deliveries_count', COUNT(*),
        'today_earnings', COALESCE(SUM(total * 0.1), 0) -- Assume 10% commission for dev
    ) INTO v_stats
    FROM orders 
    WHERE rider_id = v_rider_id AND status = 'DELIVERED';

    RETURN jsonb_build_object(
        'rider_id', v_rider_id,
        'active_orders', COALESCE(v_active_orders, '[]'::jsonb),
        'available_orders', COALESCE(v_available_orders, '[]'::jsonb),
        'stats', v_stats
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. 📝 VENDOR ORDER ACTION (Accept/Reject)
CREATE OR REPLACE FUNCTION vendor_set_order_status_v1(
    p_order_id UUID, 
    p_vendor_auth_id UUID, 
    p_new_status TEXT, 
    p_rejection_reason TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    v_vendor_id UUID;
    v_customer_id TEXT;
BEGIN
    SELECT id INTO v_vendor_id FROM vendors WHERE auth_id = p_vendor_auth_id LIMIT 1;
    
    -- Safety check: Verification of ownership
    IF NOT EXISTS (SELECT 1 FROM orders WHERE id = p_order_id AND vendor_id = v_vendor_id) THEN
        RAISE EXCEPTION 'Unauthorized: This order does not belong to your shop.';
    END IF;

    -- Update Order
    UPDATE orders 
    SET status = UPPER(p_new_status), 
        rejection_reason = p_rejection_reason,
        updated_at = NOW()
    WHERE id = p_order_id;

    -- Notify Customer
    SELECT customer_id INTO v_customer_id FROM orders WHERE id = p_order_id;
    INSERT INTO notifications (user_id, title, message)
    VALUES (
        v_customer_id, 
        'Order ' || INITCAP(p_new_status), 
        CASE 
            WHEN p_new_status = 'ACCEPTED' THEN 'Your order has been accepted by the restaurant.'
            WHEN p_new_status = 'REJECTED' THEN 'The restaurant rejected your order: ' || COALESCE(p_rejection_reason, 'No reason provided')
            ELSE 'Your order status updated to ' || p_new_status
        END
    );

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. 🛵 RIDER LOGISTICS LAYER
-- Specialized tracking table for "Heatmap/Live" that doesn't bloat the main orders table
CREATE TABLE IF NOT EXISTS rider_live_gps (
    rider_id UUID PRIMARY KEY REFERENCES delivery_riders(id) ON DELETE CASCADE,
    lat DOUBLE PRECISION NOT NULL,
    lng DOUBLE PRECISION NOT NULL,
    bearing DOUBLE PRECISION DEFAULT 0,
    speed DOUBLE PRECISION DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Optimization: Enable Realtime for this table
ALTER TABLE rider_live_gps REPLICA IDENTITY FULL;

CREATE OR REPLACE FUNCTION rider_update_gps_v1(
    p_rider_auth_id UUID,
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION,
    p_bearing DOUBLE PRECISION DEFAULT 0,
    p_speed DOUBLE PRECISION DEFAULT 0
)
RETURNS BOOLEAN AS $$
DECLARE
    v_rider_id UUID;
BEGIN
    SELECT id INTO v_rider_id FROM delivery_riders WHERE auth_id = p_rider_auth_id LIMIT 1;
    
    INSERT INTO rider_live_gps (rider_id, lat, lng, bearing, speed, updated_at)
    VALUES (v_rider_id, p_lat, p_lng, p_bearing, p_speed, NOW())
    ON CONFLICT (rider_id) DO UPDATE SET
        lat = EXCLUDED.lat,
        lng = EXCLUDED.lng,
        bearing = EXCLUDED.bearing,
        speed = EXCLUDED.speed,
        updated_at = NOW();

    -- Also update the legacy column in delivery_riders for backward compatibility
    UPDATE delivery_riders 
    SET current_lat = p_lat, current_lng = p_lng 
    WHERE id = v_rider_id;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
