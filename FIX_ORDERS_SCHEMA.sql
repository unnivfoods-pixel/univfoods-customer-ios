
-- Add missing payment_id column to orders table
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS payment_id text;

-- Ensure other potentially missing columns from cart_screen.dart are present
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS item_total numeric DEFAULT 0;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_fee numeric DEFAULT 0;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS platform_fee numeric DEFAULT 0;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS gst numeric DEFAULT 0;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS tip_amount numeric DEFAULT 0;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_address text;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS pickup_lat double precision;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS pickup_lng double precision;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS payment_method text;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS payment_status text DEFAULT 'PENDING';
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS zone_id uuid;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS special_instructions text;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS promo_code text;

-- Enable Realtime for orders just in case
ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END;
