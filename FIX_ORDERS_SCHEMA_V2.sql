
DO $$ 
BEGIN
    -- Add missing payment_id column to orders table
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='payment_id') THEN
        ALTER TABLE public.orders ADD COLUMN payment_id text;
    END IF;

    -- Ensure other potentially missing columns from cart_screen.dart are present
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='item_total') THEN
        ALTER TABLE public.orders ADD COLUMN item_total numeric DEFAULT 0;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='delivery_fee') THEN
        ALTER TABLE public.orders ADD COLUMN delivery_fee numeric DEFAULT 0;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='platform_fee') THEN
        ALTER TABLE public.orders ADD COLUMN platform_fee numeric DEFAULT 0;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='gst') THEN
        ALTER TABLE public.orders ADD COLUMN gst numeric DEFAULT 0;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='tip_amount') THEN
        ALTER TABLE public.orders ADD COLUMN tip_amount numeric DEFAULT 0;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='delivery_address') THEN
        ALTER TABLE public.orders ADD COLUMN delivery_address text;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='pickup_lat') THEN
        ALTER TABLE public.orders ADD COLUMN pickup_lat double precision;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='pickup_lng') THEN
        ALTER TABLE public.orders ADD COLUMN pickup_lng double precision;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='payment_method') THEN
        ALTER TABLE public.orders ADD COLUMN payment_method text;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='payment_status') THEN
        ALTER TABLE public.orders ADD COLUMN payment_status text DEFAULT 'PENDING';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='special_instructions') THEN
        ALTER TABLE public.orders ADD COLUMN special_instructions text;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='promo_code') THEN
        ALTER TABLE public.orders ADD COLUMN promo_code text;
    END IF;

END $$;
