-- 🚀 REALTIME ACTION INFRASTRUCTURE (SETTINGS, PAYMENTS & BOOTSTRAP)
BEGIN;

-- 1. NOTIFICATION PREFERENCES TABLE
CREATE TABLE IF NOT EXISTS public.user_settings (
    user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    order_updates boolean DEFAULT true,
    promotions boolean DEFAULT true,
    system_alerts boolean DEFAULT true,
    push_notifications boolean DEFAULT true,
    email_digest boolean DEFAULT false,
    sms_updates boolean DEFAULT false,
    updated_at timestamptz DEFAULT now()
);

-- Enable Realtime for Settings
ALTER TABLE public.user_settings REPLICA IDENTITY FULL;

-- 2. PAYMENT METHODS TABLE
CREATE TABLE IF NOT EXISTS public.user_payment_methods (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type text NOT NULL, -- UPI, CARD, WALLET
    label text NOT NULL, -- "Personal UPI", "Work Card", etc.
    value text NOT NULL, -- UPI ID, Masked Card Number, Account Email
    issuer text, -- GPay, PhonePe, Visa, HDFC, etc.
    is_default boolean DEFAULT false,
    created_at timestamptz DEFAULT now()
);

-- Enable Realtime for Payment Methods
ALTER TABLE public.user_payment_methods REPLICA IDENTITY FULL;

-- 3. RLS POLICIES
ALTER TABLE public.user_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own settings" ON public.user_settings;
CREATE POLICY "Users can manage their own settings" ON public.user_settings
    FOR ALL USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

ALTER TABLE public.user_payment_methods ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own payment methods" ON public.user_payment_methods;
CREATE POLICY "Users can manage their own payment methods" ON public.user_payment_methods
    FOR ALL USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 4. HYPER-BOOTSTRAP V2 (UPGRADED)
-- This function returns EVERYTHING a user needs in ONE call.
CREATE OR REPLACE FUNCTION public.get_user_bootstrap_data(p_user_id uuid)
RETURNS json AS $$
DECLARE
    v_profile json;
    v_wallet json;
    v_active_orders json;
    v_settings json;
    v_payment_methods json;
BEGIN
    -- Get Profile
    SELECT row_to_json(p) INTO v_profile FROM public.customer_profiles p WHERE id = p_user_id;
    
    -- Get Wallet (Create if missing)
    INSERT INTO public.wallets (user_id, balance)
    VALUES (p_user_id, 0.00)
    ON CONFLICT (user_id) DO NOTHING;
    
    SELECT row_to_json(w) INTO v_wallet FROM public.wallets w WHERE user_id = p_user_id;
    
    -- Get Active Orders (Last 10)
    SELECT json_agg(o) INTO v_active_orders 
    FROM (
        SELECT * FROM public.orders 
        WHERE customer_id = p_user_id 
        ORDER BY created_at DESC 
        LIMIT 10
    ) o;

    -- Get Settings (Create if missing)
    INSERT INTO public.user_settings (user_id)
    VALUES (p_user_id)
    ON CONFLICT (user_id) DO NOTHING;

    SELECT row_to_json(s) INTO v_settings FROM public.user_settings s WHERE user_id = p_user_id;

    -- Get Payment Methods
    SELECT json_agg(m) INTO v_payment_methods 
    FROM public.user_payment_methods m 
    WHERE user_id = p_user_id;

    RETURN json_build_object(
        'profile', v_profile,
        'wallet', v_wallet,
        'active_orders', v_active_orders,
        'settings', v_settings,
        'payment_methods', v_payment_methods
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
