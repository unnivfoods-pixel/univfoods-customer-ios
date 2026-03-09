-- 🛰️ V7: UNIFIED PARTNER AUTH & LOGISTICS (VENDORS + RIDERS)
-- Implements: Real-time Signup, Admin Approval, and Instant Dashboard Sync for both roles.

BEGIN;

-- 1. ENHANCE DELIVERY RIDERS TABLE
ALTER TABLE public.delivery_riders ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE public.delivery_riders ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE public.delivery_riders ADD COLUMN IF NOT EXISTS is_approved BOOLEAN DEFAULT FALSE;
ALTER TABLE public.delivery_riders ADD COLUMN IF NOT EXISTS fcm_token TEXT;

-- 2. UNIFIED APPROVAL FUNCTION
-- One click in Admin Panel -> Auth, Partner Record, and Notification all sync
CREATE OR REPLACE FUNCTION approve_partner_v7(request_id UUID)
RETURNS VOID AS $$
DECLARE
    r RECORD;
BEGIN
    SELECT * INTO r FROM public.registration_requests WHERE id = request_id;

    IF (r.type = 'rider' OR r.type = 'delivery') THEN
        -- RIDER LOGIC
        INSERT INTO public.delivery_riders (
            id, name, phone, email, is_approved, status
        ) VALUES (
            r.owner_id, r.name, r.phone, r.email, TRUE, 'Offline'
        )
        ON CONFLICT (id) DO UPDATE SET
            is_approved = TRUE,
            name = EXCLUDED.name,
            phone = EXCLUDED.phone;
            
        -- Broadcast to Rider
        INSERT INTO public.notifications (user_id, title, body, target_type)
        VALUES (r.owner_id, 'Fleet Commissioned!', 'Your rider profile is live. Start delivering today!', 'riders');

    ELSE
        -- VENDOR LOGIC
        INSERT INTO public.vendors (
            name, owner_id, phone, address, 
            approval_status, is_approved, status
        ) VALUES (
            r.name, r.owner_id, r.phone, r.address,
            'APPROVED', TRUE, 'ONLINE'
        )
        ON CONFLICT (owner_id) DO UPDATE SET
            approval_status = 'APPROVED',
            is_approved = TRUE,
            status = 'ONLINE';

        -- Broadcast to Vendor
        INSERT INTO public.notifications (user_id, title, body, target_type)
        VALUES (r.owner_id, 'Node Activated!', 'Your kitchen is now live on the UNIV grid.', 'vendors');
    END IF;

    -- Update Request Status
    UPDATE public.registration_requests SET status = 'approved' WHERE id = request_id;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. ENABLE REAL-TIME FOR ALL PARTNER TABLES
ALTER TABLE public.delivery_riders REPLICA IDENTITY FULL;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        BEGIN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.delivery_riders;
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
    END IF;
END $$;

NOTIFY pgrst, 'reload schema';
COMMIT;
