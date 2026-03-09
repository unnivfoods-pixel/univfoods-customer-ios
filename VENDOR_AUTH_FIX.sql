-- 🛰️ V8: VENDOR AUTH TRANSPARENCY & LOGIN FIX
-- Ensures that when a vendor applies, their credentials are fully visible and usable.

BEGIN;

-- 1. ADD EMAIL TO VENDORS FOR TRANSPARENCY
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS email TEXT;

-- 2. UPDATE APPROVAL RPC TO SYNC EMAIL
CREATE OR REPLACE FUNCTION approve_partner_v7(request_id UUID)
RETURNS VOID AS $$
DECLARE
    r RECORD;
BEGIN
    SELECT * INTO r FROM public.registration_requests WHERE id = request_id;

    IF (r.type = 'rider' OR r.type = 'delivery') THEN
        INSERT INTO public.delivery_riders (
            id, name, phone, email, is_approved, status
        ) VALUES (
            r.owner_id, r.name, r.phone, r.email, TRUE, 'Offline'
        )
        ON CONFLICT (id) DO UPDATE SET
            is_approved = TRUE,
            email = EXCLUDED.email,
            name = EXCLUDED.name,
            phone = EXCLUDED.phone;
            
        INSERT INTO public.notifications (user_id, title, body, target_type)
        VALUES (r.owner_id, 'Fleet Commissioned!', 'Your rider profile is live. Start delivering today!', 'riders');

    ELSE
        INSERT INTO public.vendors (
            name, owner_id, phone, email, address, 
            approval_status, is_approved, status
        ) VALUES (
            r.name, r.owner_id, r.phone, r.email, r.address,
            'APPROVED', TRUE, 'ONLINE'
        )
        ON CONFLICT (owner_id) DO UPDATE SET
            approval_status = 'APPROVED',
            is_approved = TRUE,
            email = EXCLUDED.email,
            status = 'ONLINE';

        INSERT INTO public.notifications (user_id, title, body, target_type)
        VALUES (r.owner_id, 'Node Activated!', 'Your kitchen is now live on the UNIV grid.', 'vendors');
    END IF;

    -- Update Request Status
    UPDATE public.registration_requests SET status = 'approved' WHERE id = request_id;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
