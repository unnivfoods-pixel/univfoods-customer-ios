-- 🚀 ULTIMATE OPERATIONAL UPGRADE
-- Implements Small but Critical Operational Features across all apps.

-- 1. SAVED ADDRESSES (Phase 1.1)
CREATE TABLE IF NOT EXISTS public.user_addresses (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) NOT NULL,
    label TEXT DEFAULT 'Home', -- Home, Work, Other
    address_line TEXT NOT NULL,
    latitude NUMERIC NOT NULL,
    longitude NUMERIC NOT NULL,
    is_default BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Trigger to ensure only one default address
CREATE OR REPLACE FUNCTION set_default_address()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.is_default THEN
        UPDATE public.user_addresses 
        SET is_default = false 
        WHERE user_id = NEW.user_id AND id != NEW.id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_set_default_address ON public.user_addresses;
CREATE TRIGGER trg_set_default_address
BEFORE INSERT OR UPDATE ON public.user_addresses
FOR EACH ROW EXECUTE PROCEDURE set_default_address();

-- 2. RATING & REVIEWS (Phase 1.3)
CREATE TABLE IF NOT EXISTS public.reviews (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id UUID REFERENCES public.orders(id) NOT NULL,
    customer_id UUID REFERENCES public.customer_profiles(id) NOT NULL,
    vendor_id UUID REFERENCES public.vendors(id),
    rider_id UUID REFERENCES public.delivery_riders(id),
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    target_type TEXT NOT NULL, -- 'vendor' or 'rider'
    is_moderated BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. COUPON SYSTEM (Phase 1.5)
CREATE TABLE IF NOT EXISTS public.coupons (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    code TEXT UNIQUE NOT NULL,
    discount_type TEXT DEFAULT 'FIXED', -- FIXED, PERCENTAGE
    discount_value NUMERIC NOT NULL,
    min_order_value NUMERIC DEFAULT 0,
    max_discount NUMERIC,
    expiry_date TIMESTAMP WITH TIME ZONE,
    usage_limit INTEGER DEFAULT 1,
    current_usage INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.coupon_usage (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    coupon_id UUID REFERENCES public.coupons(id),
    customer_id UUID REFERENCES public.customer_profiles(id),
    order_id UUID REFERENCES public.orders(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- 4. VENDOR & KITCHEN BUSY MODE (Phase 2.2, 2.3)
ALTER TABLE public.vendors
ADD COLUMN IF NOT EXISTS busy_mode_until TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS auto_accept BOOLEAN DEFAULT true;

ALTER TABLE public.products
ADD COLUMN IF NOT EXISTS is_available BOOLEAN DEFAULT true;

-- 5. DELIVERY & RIDER MONITORING (Phase 3.3, 3.6)
ALTER TABLE public.delivery_riders
ADD COLUMN IF NOT EXISTS acceptance_rate NUMERIC DEFAULT 100.0,
ADD COLUMN IF NOT EXISTS break_mode BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS battery_level INTEGER,
ADD COLUMN IF NOT EXISTS gps_enabled BOOLEAN DEFAULT true;

-- 6. ADMIN AUDIT & SYSTEM CONTROLS (Phase 4.1, 4.4)
CREATE TABLE IF NOT EXISTS public.admin_audit_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    admin_id UUID REFERENCES auth.users(id),
    action TEXT NOT NULL,
    target_table TEXT,
    target_id TEXT,
    old_value JSONB,
    new_value JSONB,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.app_versions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    platform TEXT NOT NULL, -- android, ios
    min_version TEXT NOT NULL,
    current_version TEXT NOT NULL,
    force_update BOOLEAN DEFAULT false
);

-- 7. PERFORMANCE & ANALYTICS FIELDS
ALTER TABLE public.orders
ADD COLUMN IF NOT EXISTS rejection_reason TEXT,
ADD COLUMN IF NOT EXISTS estimated_prep_time INTEGER; -- in minutes

-- 8. AUTO-CANCEL TIMEOUT LOGIC (Phase 2.1)
-- This function can be called by an edge function or a separate process
-- For SQL-only, we can flag them in a view for Admin to see or use a cron if enabled.
CREATE OR REPLACE VIEW public.pending_timeout_orders AS
SELECT id, vendor_id, customer_id
FROM public.orders
WHERE status = 'placed'
AND created_at < NOW() - INTERVAL '60 seconds';

-- 9. REALTIME BROADCASTING
ALTER PUBLICATION supabase_realtime ADD TABLE public.user_addresses;
ALTER PUBLICATION supabase_realtime ADD TABLE public.reviews;
ALTER PUBLICATION supabase_realtime ADD TABLE public.coupons;
ALTER PUBLICATION supabase_realtime ADD TABLE public.app_versions;

-- 10. SECURITY: PHONE MASKING VIEW (Phase Security)
CREATE OR REPLACE VIEW public.secure_rider_order_view AS
SELECT 
    o.id, o.status, o.total, o.address, 
    '***-***-' || RIGHT(c.phone, 4) as masked_customer_phone,
    o.customer_id, o.vendor_id
FROM public.orders o
JOIN public.customer_profiles c ON o.customer_id = c.id;
