-- 🏪 MASTER VENDOR LOGIC & ONBOARDING FIX
-- Run this in Supabase SQL Editor

-- 1. Ensure VENDORS Table has all necessary columns for Vendor App
ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS status text DEFAULT 'closed', -- open, closed
ADD COLUMN IF NOT EXISTS is_approved boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS avg_prep_time integer DEFAULT 15,
ADD COLUMN IF NOT EXISTS upi_id text,
ADD COLUMN IF NOT EXISTS bank_account_number text,
ADD COLUMN IF NOT EXISTS bank_ifsc text,
ADD COLUMN IF NOT EXISTS cuisine_type text DEFAULT 'Indian';

-- 2. ENABLE REALTIME for Vendors (for status sync)
-- (Already handled in REALTIME_RLS_FINAL_FIX, but just in case)
ALTER TABLE public.vendors REPLICA IDENTITY FULL;

-- 3. VENDOR WALLET COLUMNS (if missing from Settlement script)
ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS wallet_balance numeric DEFAULT 0.0,
ADD COLUMN IF NOT EXISTS total_earnings numeric DEFAULT 0.0;

-- 4. RLS POLICIES FOR VENDORS
ALTER TABLE public.vendors ENABLE ROW LEVEL SECURITY;

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Vendors can update their own profile' AND tablename = 'vendors') THEN
        CREATE POLICY "Vendors can update their own profile" 
        ON public.vendors FOR UPDATE 
        USING (auth.uid() = owner_id)
        WITH CHECK (auth.uid() = owner_id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Anyone can view active vendors' AND tablename = 'vendors') THEN
        CREATE POLICY "Anyone can view active vendors" 
        ON public.vendors FOR SELECT 
        USING (true);
    END IF;
END $$;

-- 5. FUNCTION: SYNC ORDER REJECTION TO ADMIN NOTIFICATIONS
CREATE OR REPLACE FUNCTION notify_order_rejection()
RETURNS TRIGGER AS $$
BEGIN
    IF (NEW.status = 'cancelled' AND NEW.cancelled_by = 'vendor') THEN
        INSERT INTO public.notifications (title, body, role, user_id)
        VALUES (
            'Order Rejected by Vendor',
            'Order #' || LEFT(NEW.id::text, 8) || ' was rejected. Reason: ' || COALESCE(NEW.cancellation_reason, 'No reason given'),
            'ADMIN',
            NULL -- Broadcast to all admins
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_notify_rejection ON public.orders;
CREATE TRIGGER tr_notify_rejection
AFTER UPDATE OF status ON public.orders
FOR EACH ROW
EXECUTE FUNCTION notify_order_rejection();

-- 6. INDEXES for Performance
CREATE INDEX IF NOT EXISTS idx_orders_vendor_id ON public.orders(vendor_id);
CREATE INDEX IF NOT EXISTS idx_products_vendor_id ON public.products(vendor_id);
