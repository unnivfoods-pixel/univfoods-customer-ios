-- 🛠 VENDOR RECOVERY & ONBOARDING (V1.2)
-- Purpose: Safely restores real vendor data from registration requests and handles existing users.

BEGIN;

-- 1. Ensure registration_requests table exists (if landing page uses it)
CREATE TABLE IF NOT EXISTS public.registration_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type TEXT,
    name TEXT,
    phone TEXT,
    email TEXT,
    message TEXT,
    address TEXT,
    status TEXT DEFAULT 'pending',
    owner_id UUID,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 2. SMART ONBOARDING LOGIC
-- This logic looks for applications from specific emails and automatically activates them as REAL vendors.
DO $$
DECLARE
    req RECORD;
BEGIN
    -- Process any pending vendor applications
    FOR req IN (SELECT * FROM public.registration_requests WHERE type = 'vendor' AND status = 'pending') LOOP
        
        -- A. Create/Update the Vendor entry
        -- We use the owner_id from the request (linked to Auth)
        IF req.owner_id IS NOT NULL THEN
            
            -- Ensure user record exists with correct role
            INSERT INTO public.users (id, role, full_name, phone, is_active)
            VALUES (req.owner_id, 'vendor', req.name, req.phone, TRUE)
            ON CONFLICT (id) DO UPDATE SET role = 'vendor', is_active = TRUE;

            -- Create the Vendor node
            INSERT INTO public.vendors (
                id, name, shop_name, address, phone, manager, 
                is_verified, is_open, status, lat, lng, radius_km
            ) 
            VALUES (
                req.owner_id, req.name, req.name, req.address, req.phone, req.name,
                TRUE, TRUE, 'ONLINE', 9.5100, 77.6300, 15.0
            )
            ON CONFLICT (id) DO UPDATE SET 
                name = EXCLUDED.name,
                shop_name = EXCLUDED.shop_name,
                is_verified = TRUE,
                is_open = TRUE,
                status = 'ONLINE';

            -- Mark request as approved
            UPDATE public.registration_requests SET status = 'approved' WHERE id = req.id;
            
            RAISE NOTICE 'Restored Vendor: %', req.name;
        END IF;
    END LOOP;
END $$;

COMMIT;
