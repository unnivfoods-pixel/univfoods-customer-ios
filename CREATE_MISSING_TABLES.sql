-- 🔧 CREATE MISSING TABLES BEFORE APPLYING RLS
-- Run this FIRST before CRITICAL_DATA_PRIVACY_FIX.sql

-- ============================================
-- 1. CREATE FAVORITES TABLE (if not exists)
-- ============================================

CREATE TABLE IF NOT EXISTS public.favorites (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at timestamptz DEFAULT now(),
    user_id uuid NOT NULL,
    product_id uuid REFERENCES public.products(id) ON DELETE CASCADE,
    vendor_id uuid REFERENCES public.vendors(id) ON DELETE CASCADE,
    UNIQUE(user_id, product_id),
    UNIQUE(user_id, vendor_id)
);

-- Enable RLS
ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.favorites REPLICA IDENTITY FULL;

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_favorites_user ON public.favorites(user_id);
CREATE INDEX IF NOT EXISTS idx_favorites_product ON public.favorites(product_id);
CREATE INDEX IF NOT EXISTS idx_favorites_vendor ON public.favorites(vendor_id);

-- ============================================
-- 2. CREATE USER_ADDRESSES TABLE (if not exists)
-- ============================================

CREATE TABLE IF NOT EXISTS public.user_addresses (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    user_id uuid NOT NULL,
    address_type text DEFAULT 'home', -- 'home', 'work', 'other'
    address_line1 text NOT NULL,
    address_line2 text,
    landmark text,
    city text NOT NULL,
    state text NOT NULL,
    pincode text NOT NULL,
    latitude double precision,
    longitude double precision,
    is_default boolean DEFAULT false,
    contact_name text,
    contact_phone text
);

-- Enable RLS
ALTER TABLE public.user_addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_addresses REPLICA IDENTITY FULL;

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_user_addresses_user ON public.user_addresses(user_id);
CREATE INDEX IF NOT EXISTS idx_user_addresses_default ON public.user_addresses(user_id, is_default);

-- ============================================
-- 3. VERIFY CHAT_MESSAGES TABLE EXISTS
-- ============================================

-- This should already exist from COMPLETE_ORDER_TRACKING_FIX.sql
-- But let's ensure it exists
CREATE TABLE IF NOT EXISTS public.chat_messages (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at timestamptz DEFAULT now(),
    order_id uuid REFERENCES public.orders(id) ON DELETE CASCADE,
    sender_id uuid NOT NULL,
    sender_role text NOT NULL, -- 'CUSTOMER', 'RIDER', 'VENDOR'
    message text NOT NULL,
    is_read boolean DEFAULT false,
    attachment_url text
);

-- Enable RLS
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages REPLICA IDENTITY FULL;

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_chat_order ON public.chat_messages(order_id);
CREATE INDEX IF NOT EXISTS idx_chat_sender ON public.chat_messages(sender_id);

-- ============================================
-- 4. UPDATE REALTIME PUBLICATION
-- ============================================

-- Drop and recreate publication to include all tables
DROP PUBLICATION IF EXISTS supabase_realtime;

CREATE PUBLICATION supabase_realtime FOR TABLE 
    public.orders, 
    public.delivery_riders, 
    public.vendors, 
    public.customer_profiles,
    public.notifications,
    public.chat_messages,
    public.favorites,
    public.user_addresses,
    public.products,
    public.categories;

-- ============================================
-- ✅ VERIFICATION
-- ============================================

-- Check if all tables exist
SELECT 
    tablename,
    CASE WHEN rowsecurity THEN '✅ RLS Enabled' ELSE '❌ RLS Disabled' END as rls_status
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('favorites', 'user_addresses', 'chat_messages', 'orders', 'customer_profiles')
ORDER BY tablename;

-- ✅ DONE! Now you can run CRITICAL_DATA_PRIVACY_FIX.sql
