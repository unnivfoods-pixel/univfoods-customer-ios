-- 🚨 GLOBAL LOGISTICS CASE & DATA SYNC (MASTER FIX)
-- 1. Harmonize casing: All statuses must be UPPERCASE (PLACED, ACCEPTED, PREPARING, READY, DELIVERED, CANCELLED)
-- 2. Fix schema mismatch: customer_id needs to be TEXT to support 'guest_tester'
-- 3. Bootstrap fix: Merge active and recent orders for instant UI recovery on restart.

BEGIN;

-- A. SCHEMA RECOVERY
-- Remove foreign key constraint if it exists to allow TEXT conversion
DO $$ 
BEGIN
    ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_customer_id_fkey;
    ALTER TABLE public.orders ALTER COLUMN customer_id TYPE TEXT;
    
    -- Ensure status is TEXT
    ALTER TABLE public.orders ALTER COLUMN status TYPE TEXT;
    
    -- Add is_settled if missing
    ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS is_settled BOOLEAN DEFAULT false;
END $$;

-- B. DATA NORMALIZATION (Capitalize all statuses)
UPDATE public.orders SET status = UPPER(status);
UPDATE public.orders SET status = 'PLACED' WHERE status = 'PENDING'; -- Standardize
UPDATE public.orders SET status = 'READY' WHERE status = 'ORDER READY';

-- C. MASTER STATUS RPC FIX (UPPERCASE ENFORCEMENT)
CREATE OR REPLACE FUNCTION public.update_order_status_v3(
    p_order_id TEXT,
    p_new_status TEXT
)
RETURNS VOID AS $$
BEGIN
    UPDATE public.orders 
    SET status = UPPER(p_new_status),
        is_settled = CASE WHEN UPPER(p_new_status) = 'DELIVERED' OR UPPER(p_new_status) = 'CANCELLED' THEN true ELSE is_settled END
    WHERE id::text = p_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- D. MASTER PLACEMENT RPC FIX
CREATE OR REPLACE FUNCTION public.place_order_v3(
    p_customer_id TEXT,
    p_vendor_id UUID,
    p_items JSONB,
    p_total DOUBLE PRECISION,
    p_address TEXT,
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION,
    p_payment_method TEXT DEFAULT 'COD',
    p_instructions TEXT DEFAULT '',
    p_address_id UUID DEFAULT NULL,
    p_payment_status TEXT DEFAULT 'PENDING',
    p_payment_id TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_order_id UUID;
    v_pickup_otp TEXT;
    v_delivery_otp TEXT;
BEGIN
    v_pickup_otp := floor(random() * 9000 + 1000)::text;
    v_delivery_otp := floor(random() * 9000 + 1000)::text;

    INSERT INTO public.orders (
        customer_id, vendor_id, items, total, address, 
        delivery_lat, delivery_lng,
        status, payment_method, payment_status, payment_id,
        pickup_otp, delivery_otp, delivery_address_id, cooking_instructions
    ) VALUES (
        p_customer_id, p_vendor_id, p_items, p_total, p_address, 
        p_lat, p_lng,
        'PLACED', UPPER(p_payment_method), UPPER(p_payment_status), p_payment_id,
        v_pickup_otp, v_delivery_otp, p_address_id, p_instructions
    ) RETURNING id INTO v_order_id;

    RETURN v_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- E. BOOTSTRAP GEYSER FIX (MERGED HISTORY)
CREATE OR REPLACE FUNCTION public.get_user_bootstrap_data(p_user_id text)
RETURNS json AS $$
DECLARE
    v_profile json;
    v_wallet json;
    v_addresses json;
    v_all_orders json;
BEGIN
    -- Profile
    SELECT row_to_json(p) INTO v_profile FROM public.customer_profiles p WHERE p.id::text = p_user_id;
    
    -- Wallet
    SELECT row_to_json(w) INTO v_wallet FROM public.wallets w WHERE w.user_id::text = p_user_id;
    IF v_wallet IS NULL THEN
        v_wallet := json_build_object('balance', 0, 'user_id', p_user_id);
    END IF;

    -- Addresses
    SELECT json_agg(a) INTO v_addresses FROM public.user_addresses a WHERE a.user_id::text = p_user_id;

    -- COMBINED ORDERS (Active + Recent 20)
    -- This ensures the Orders page is NEVER blank after restart.
    SELECT json_agg(o) INTO v_all_orders FROM (
        SELECT orders.*, 
               row_to_json(vendors) as vendors,
               row_to_json(delivery_riders) as delivery_riders
        FROM public.orders 
        LEFT JOIN public.vendors ON orders.vendor_id = vendors.id
        LEFT JOIN public.delivery_riders ON orders.delivery_partner_id = delivery_riders.id
        WHERE customer_id::text = p_user_id 
        ORDER BY orders.created_at DESC 
        LIMIT 20
    ) o;

    RETURN json_build_object(
        'profile', v_profile,
        'wallet', v_wallet,
        'addresses', COALESCE(v_addresses, '[]'::json),
        'active_orders', COALESCE(v_all_orders, '[]'::json), -- Use all orders for active_orders to populate Store
        'unread_notifications', (SELECT count(*)::int FROM public.notifications WHERE user_id::text = p_user_id AND read_status = false)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- F. NOTIFICATION TRIGGER CASE SYNC
CREATE OR REPLACE FUNCTION handle_core_notifications_v3()
RETURNS TRIGGER AS $$
DECLARE
    v_customer_id text;
    v_vendor_id uuid;
    v_rider_name text;
    v_order_short_id text;
BEGIN
    v_order_short_id := SUBSTRING(NEW.id::text, 1, 8);
    v_customer_id := NEW.customer_id;
    v_vendor_id := NEW.vendor_id;

    IF (TG_OP = 'INSERT') THEN
        INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
        VALUES (v_customer_id::uuid, 'customer', 'Order Confirmed 🎉', 'Your order #' || v_order_short_id || ' has been placed successfully.', NEW.id, 'order');
    END IF;

    IF (TG_OP = 'UPDATE') THEN
        IF (UPPER(NEW.status) != UPPER(OLD.status)) THEN
            CASE UPPER(NEW.status)
                WHEN 'ACCEPTED' THEN
                    INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                    VALUES (v_customer_id::uuid, 'customer', 'Order Accepted 👨‍🍳', 'The restaurant has started preparing your order.', NEW.id, 'order');
                WHEN 'PREPARING' THEN
                    INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                    VALUES (v_customer_id::uuid, 'customer', 'Preparing Your Food', 'Your delicious meal is being prepared.', NEW.id, 'order');
                WHEN 'READY' THEN
                    INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                    VALUES (v_customer_id::uuid, 'customer', 'Ready for Extraction', 'Rider is arriving to pick up your order.', NEW.id, 'order');
                WHEN 'PICKED_UP' THEN
                    INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                    VALUES (v_customer_id::uuid, 'customer', 'Out for Delivery 🚴', 'Your order is on the way!', NEW.id, 'order');
                WHEN 'DELIVERED' THEN
                    INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                    VALUES (v_customer_id::uuid, 'customer', 'Delivered 🎉', 'Enjoy your meal! ⭐', NEW.id, 'order');
                WHEN 'CANCELLED' THEN
                    INSERT INTO public.notifications (user_id, app_type, title, message, order_id, type)
                    VALUES (v_customer_id::uuid, 'customer', 'Order Cancelled', 'Your order was cancelled. Refund initiated if applicable.', NEW.id, 'order');
                ELSE
            END CASE;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMIT;
