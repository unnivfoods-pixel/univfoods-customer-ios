
-- COMPREHENSIVE FIX FOR ORDERS TABLE
-- This ensures all columns required by CartScreen.dart are present

DO $$ 
BEGIN
    -- 1. Essential Columns for Order Processing
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='payment_id') THEN
        ALTER TABLE public.orders ADD COLUMN payment_id text;
    END IF;

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

    -- 2. Delivery Management Columns
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='delivery_partner_id') THEN
        ALTER TABLE public.orders ADD COLUMN delivery_partner_id uuid REFERENCES public.delivery_riders(id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='zone_id') THEN
        ALTER TABLE public.orders ADD COLUMN zone_id uuid;
    END IF;

    -- 3. Rider Table Enhancements for Admin Approval
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='delivery_riders' AND column_name='is_approved') THEN
        ALTER TABLE public.delivery_riders ADD COLUMN is_approved boolean DEFAULT false;
    END IF;

    -- Ensure 'status' column in riders is text and has default
    ALTER TABLE public.delivery_riders ALTER COLUMN status SET DEFAULT 'Offline';

END $$;

-- Enable Realtime for critical tables
ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
ALTER PUBLICATION supabase_realtime ADD TABLE public.delivery_riders;
ALTER PUBLICATION supabase_realtime ADD TABLE public.registrations;
