-- =========================================================
-- ADVANCED DELIVERY ZONES SCHEMA
-- Enhances delivery_zones with operational logic & geometry.
-- =========================================================

-- 1. Add columns to public.delivery_zones
ALTER TABLE public.delivery_zones 
ADD COLUMN IF NOT EXISTS type text DEFAULT 'allowed', -- 'allowed', 'blocked', 'surge'
ADD COLUMN IF NOT EXISTS coordinates jsonb, -- Array of {lat, lng}
ADD COLUMN IF NOT EXISTS base_delivery_fee decimal DEFAULT 40,
ADD COLUMN IF NOT EXISTS per_km_charge decimal DEFAULT 10,
ADD COLUMN IF NOT EXISTS surge_multiplier decimal DEFAULT 1.0,
ADD COLUMN IF NOT EXISTS open_time text DEFAULT '06:00',
ADD COLUMN IF NOT EXISTS close_time text DEFAULT '23:00',
ADD COLUMN IF NOT EXISTS active_days jsonb DEFAULT '["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]',
ADD COLUMN IF NOT EXISTS feature_flags jsonb DEFAULT '{"rain_mode": false, "cod_allowed": true, "wallet_cashback": 0}';

-- 2. Add description if missing (though the promo script had it)
-- ALTER TABLE public.delivery_zones ADD COLUMN IF NOT EXISTS description text;

-- 3. Enable Realtime if not already
ALTER PUBLICATION supabase_realtime ADD TABLE public.delivery_zones;

-- 4. Initial Seed (Optional: Hydrate a sample zone if table is empty)
-- INSERT INTO public.delivery_zones (name, base_delivery_fee, per_km_charge, type)
-- VALUES ('Hyderabad Core', 45, 12, 'allowed')
-- ON CONFLICT DO NOTHING;
