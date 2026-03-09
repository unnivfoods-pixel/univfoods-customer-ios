-- 🚀 ULTIMATE STABILITY FIX v76.0 (COALESCE TYPE MISMATCH FIX)
-- 🎯 Goal: Fix "COALESCE types text and uuid cannot be matched" error during checkout.
-- 🛠️ Problem: Trigger function fn_unified_notification_v75 uses COALESCE on mixed UUID and TEXT columns.

BEGIN;

-- 1. FIX THE TRIGGER FUNCTION (v76)
CREATE OR REPLACE FUNCTION public.fn_unified_notification_v76()
RETURNS TRIGGER AS $$
DECLARE
    v_cust_id TEXT;
    v_vend_id TEXT;
    v_rid_id TEXT;
    v_order_id TEXT := NEW.id::TEXT;
    v_short_id TEXT := LEFT(v_order_id, 8);
    -- 🛡️ Fix COALESCE: Cast to TEXT inside COALESCE
    v_status TEXT := COALESCE(NEW.order_status::TEXT, NEW.status::TEXT, 'PENDING');
    v_total TEXT := COALESCE(NEW.total_amount::TEXT, NEW.total::TEXT, '0');
    v_shop_name TEXT;
BEGIN
    -- 🛡️ Fix COALESCE/Casting: Always use ::TEXT for IDs to handle UUID/Firebase string mix
    v_cust_id := NEW.customer_id::TEXT;
    v_vend_id := NEW.vendor_id::TEXT;
    
    -- 🛡️ CRITICAL FIX: Cast each column to TEXT BEFORE COALESCE to avoid type mismatch (Code: 42804)
    v_rid_id := COALESCE(
        NEW.rider_id::TEXT, 
        NEW.delivery_partner_id::TEXT, 
        NEW.delivery_id::TEXT
    );

    -- Get Shop Name (Defensive Join)
    SELECT name INTO v_shop_name FROM public.vendors WHERE id::TEXT = v_vend_id LIMIT 1;
    v_shop_name := COALESCE(v_shop_name, 'The Restaurant');

    -- ACTION: ON INSERT (New Order)
    IF (TG_OP = 'INSERT') THEN
        -- Notify Customer
        INSERT INTO public.notifications (user_id, user_role, role, title, message, body, type, event_type, order_id)
        VALUES (v_cust_id, 'customer', 'CUSTOMER', '🍛 Order Placed!', 'Order #' || v_short_id || ' received. Total: ₹' || v_total, 'Order #' || v_short_id || ' received. Total: ₹' || v_total, 'order', 'ORDER_PLACED', v_order_id);
        
        -- Notify Vendor
        INSERT INTO public.notifications (user_id, user_role, role, title, message, body, type, event_type, order_id)
        VALUES (v_vend_id, 'vendor', 'VENDOR', '🚀 New Order!', 'New order #' || v_short_id || ' (₹' || v_total || ') from customer.', 'New order #' || v_short_id || ' (₹' || v_total || ') from customer.', 'order', 'NEW_ORDER', v_order_id);
    END IF;

    -- ACTION: ON UPDATE (Status Change)
    IF (TG_OP = 'UPDATE' AND (COALESCE(NEW.order_status, '') IS DISTINCT FROM COALESCE(OLD.order_status, '') OR COALESCE(NEW.status, '') IS DISTINCT FROM COALESCE(OLD.status, ''))) THEN
        
        -- ACCEPTED / CONFIRMED
        IF (v_status IN ('ACCEPTED', 'CONFIRMED')) THEN
            INSERT INTO public.notifications (user_id, user_role, role, title, message, body, type, event_type, order_id)
            VALUES (v_cust_id, 'customer', 'CUSTOMER', '✅ Order Accepted', v_shop_name || ' is preparing your food.', v_shop_name || ' is preparing your food.', 'order', 'ORDER_ACCEPTED', v_order_id);
        END IF;

        -- RIDER ASSIGNED
        IF (v_status = 'RIDER_ASSIGNED' OR (NEW.rider_id IS NOT NULL AND OLD.rider_id IS NULL)) THEN
            INSERT INTO public.notifications (user_id, user_role, role, title, message, body, type, event_type, order_id)
            VALUES (v_cust_id, 'customer', 'CUSTOMER', '🛵 Rider Assigned', 'A delivery partner is on the way to the restaurant.', 'A delivery partner is on the way to the restaurant.', 'order', 'RIDER_ASSIGNED', v_order_id);
            
            IF v_rid_id IS NOT NULL THEN
                INSERT INTO public.notifications (user_id, user_role, role, title, message, body, type, event_type, order_id)
                VALUES (v_rid_id, 'delivery', 'RIDER', '🛎️ New Task', 'Pickup from ' || v_shop_name || ' for Order #' || v_short_id, 'Pickup from ' || v_shop_name || ' for Order #' || v_short_id, 'order', 'TASK_ASSIGNED', v_order_id);
            END IF;
        END IF;

        -- PICKED_UP / TRANSIT
        IF (v_status IN ('PICKED_UP', 'TRANSIT', 'ON_THE_WAY')) THEN
            INSERT INTO public.notifications (user_id, user_role, role, title, message, body, type, event_type, order_id)
            VALUES (v_cust_id, 'customer', 'CUSTOMER', '🚀 Out for Delivery', 'Your food has been picked up and is on the way!', 'Your food has been picked up and is on the way!', 'order', 'PICKED_UP', v_order_id);
        END IF;

        -- DELIVERED
        IF (v_status = 'DELIVERED') THEN
            INSERT INTO public.notifications (user_id, user_role, role, title, message, body, type, event_type, order_id)
            VALUES (v_cust_id, 'customer', 'CUSTOMER', '🎉 Enjoy your meal!', 'Order delivered successfully. Rate us!', 'Order delivered successfully. Rate us!', 'order', 'DELIVERED', v_order_id);
            
            IF v_rid_id IS NOT NULL THEN
                INSERT INTO public.notifications (user_id, user_role, role, title, message, body, type, event_type, order_id)
                VALUES (v_rid_id, 'delivery', 'RIDER', '✅ Completed', 'Goal achieved! Order #' || v_short_id || ' delivered.', 'Goal achieved! Order #' || v_short_id || ' delivered.', 'order', 'DELIVERY_DONE', v_order_id);
            END IF;
        END IF;

        -- CANCELLED
        IF (v_status = 'CANCELLED') THEN
            INSERT INTO public.notifications (user_id, user_role, role, title, message, body, type, event_type, order_id)
            VALUES (v_cust_id, 'customer', 'CUSTOMER', '❌ Order Cancelled', 'Your order #' || v_short_id || ' was cancelled.', 'Your order #' || v_short_id || ' was cancelled.', 'order', 'ORDER_CANCELLED', v_order_id);
        END IF;

    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. RE-ATTACH TO ORDERS TABLE
DROP TRIGGER IF EXISTS tr_unified_notifications_v75 ON public.orders;
DROP TRIGGER IF EXISTS tr_unified_notifications_v76 ON public.orders;

CREATE TRIGGER tr_unified_notifications_v76
AFTER INSERT OR UPDATE ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.fn_unified_notification_v76();

-- 3. FIX ORDER DETAILS VIEW (Identified secondary potential fault)
CREATE OR REPLACE VIEW public.order_details_v3 AS
SELECT 
    o.id::TEXT, 
    o.customer_id::TEXT, 
    o.vendor_id::TEXT, 
    o.rider_id::TEXT, 
    COALESCE(o.total_amount, o.total)::NUMERIC as total, 
    COALESCE(o.order_status, o.status, 'PENDING')::TEXT as status, 
    o.items,
    o.delivery_lat, 
    o.delivery_lng, 
    COALESCE(o.delivery_address, o.delivery_address_text)::TEXT as delivery_address,
    o.created_at, 
    o.payment_method,
    v.name as vendor_name, 
    v.address as vendor_address, 
    v.phone as vendor_phone,
    -- 🛡️ Fix display_customer_name COALESCE to avoid UUID/Text mismatch
    COALESCE(p.full_name::TEXT, o.customer_id::TEXT, 'Guest User') as customer_name,
    cp.phone::TEXT as customer_phone
FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id::TEXT = v.id::TEXT
LEFT JOIN public.customer_profiles cp ON o.customer_id::TEXT = cp.id::TEXT
LEFT JOIN public.customer_profiles p ON o.customer_id::TEXT = p.id::TEXT;

-- 4. FIX TRACKING VIEW (AGGRESSIVE TYPE ALIGNMENT)
CREATE OR REPLACE VIEW public.order_tracking_stabilized_v1 AS
SELECT 
    o.id::TEXT AS order_id,
    o.id::TEXT AS id,
    o.customer_id::TEXT,
    o.vendor_id::TEXT,
    o.rider_id::TEXT,
    COALESCE(o.order_status, o.status, 'PLACED')::TEXT as order_status,
    o.payment_status::TEXT,
    o.payment_method::TEXT,
    COALESCE(o.total_amount, o.total)::NUMERIC as total_amount,
    COALESCE(o.delivery_address, 'Address not found')::TEXT as delivery_address,
    o.delivery_lat::DOUBLE PRECISION,
    o.delivery_lng::DOUBLE PRECISION,
    o.vendor_lat::DOUBLE PRECISION,
    o.vendor_lng::DOUBLE PRECISION,
    o.rider_lat::DOUBLE PRECISION,
    o.rider_lng::DOUBLE PRECISION,
    o.items,
    o.created_at,
    o.updated_at,
    CASE 
        WHEN COALESCE(o.order_status, o.status) = 'PAYMENT_PENDING' THEN 'Payment Pending'
        WHEN COALESCE(o.order_status, o.status) = 'PLACED' THEN 'Order Placed'
        WHEN COALESCE(o.order_status, o.status) = 'ACCEPTED' THEN 'Preparing'
        WHEN COALESCE(o.order_status, o.status) = 'COOKING' THEN 'Cooking'
        WHEN COALESCE(o.order_status, o.status) = 'PICKED_UP' THEN 'Out for Delivery'
        WHEN COALESCE(o.order_status, o.status) = 'DELIVERED' THEN 'Delivered'
        WHEN COALESCE(o.order_status, o.status) = 'CANCELLED' THEN 'Cancelled'
        ELSE COALESCE(o.order_status, o.status)
    END AS status_display,
    CASE 
        WHEN COALESCE(o.order_status, o.status) = 'PLACED' THEN 1
        WHEN COALESCE(o.order_status, o.status) = 'ACCEPTED' THEN 2
        WHEN COALESCE(o.order_status, o.status) = 'COOKING' THEN 3
        WHEN COALESCE(o.order_status, o.status) = 'PICKED_UP' THEN 4
        WHEN COALESCE(o.order_status, o.status) = 'DELIVERED' THEN 5
        ELSE 1
    END AS current_step,
    v.name::TEXT AS vendor_name,
    COALESCE(v.image_url, v.banner_url)::TEXT AS vendor_image,
    v.logo_url::TEXT AS vendor_logo,
    v.phone::TEXT AS vendor_phone,
    v.address::TEXT AS vendor_address,
    r.full_name::TEXT AS rider_name,
    r.phone::TEXT AS rider_phone,
    r.avatar_url::TEXT AS rider_avatar,
    r.rating::TEXT AS rider_rating,
    r.vehicle_details::TEXT AS rider_vehicle
FROM public.orders o
LEFT JOIN public.vendors v ON o.vendor_id::TEXT = v.id::TEXT
LEFT JOIN public.delivery_riders r ON o.rider_id::TEXT = r.id::TEXT;

COMMIT;

SELECT '✅ ULTIMATE STABILITY FIX v76.0 INSTALLED!' as status;
