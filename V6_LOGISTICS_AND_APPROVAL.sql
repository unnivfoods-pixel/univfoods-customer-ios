-- 🛰️ V6: UNIFIED VENDOR AUTH & REAL-TIME LOGISTICS
-- Implements: Real-time Signup, Admin Approval, and Instant Dashboard Sync

BEGIN;

-- 1. ENHANCE VENDORS TABLE
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS logo_url TEXT;
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS banner_url TEXT;
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS approval_status TEXT DEFAULT 'PENDING'; -- PENDING, APPROVED, REJECTED
ALTER TABLE public.vendors ADD COLUMN IF NOT EXISTS is_approved BOOLEAN DEFAULT FALSE;

-- Ensure owner_id is unique so we can use ON CONFLICT
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'vendors_owner_id_key') THEN
        ALTER TABLE public.vendors ADD CONSTRAINT vendors_owner_id_key UNIQUE (owner_id);
    END IF;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Constraint already exists or unique violation present.';
END $$;

-- 2. CREATE REGISTRATION REQUESTS TABLE (If missing)
CREATE TABLE IF NOT EXISTS public.registration_requests (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    owner_id uuid REFERENCES auth.users(id),
    name text NOT NULL,
    email text NOT NULL,
    phone text,
    address text,
    type text DEFAULT 'vendor', -- vendor, rider
    status text DEFAULT 'pending',
    message text,
    created_at timestamptz DEFAULT now()
);

-- 3. ENABLE REAL-TIME FOR REQUESTS
ALTER TABLE public.registration_requests REPLICA IDENTITY FULL;
ALTER TABLE public.vendors REPLICA IDENTITY FULL;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        -- Safely add tables
        BEGIN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.registration_requests;
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
        BEGIN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.vendors;
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
    END IF;
END $$;

-- 4. POLICIES
ALTER TABLE public.registration_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public insert requests" ON public.registration_requests;
CREATE POLICY "Public insert requests" ON public.registration_requests FOR INSERT WITH CHECK (true);
DROP POLICY IF EXISTS "Admin read requests" ON public.registration_requests;
CREATE POLICY "Admin read requests" ON public.registration_requests FOR SELECT USING (true);

-- 5. TRIPLE THREAT APPROVAL FUNCTION
-- One click in Admin Panel -> Auth, Vendor Record, and Notification all sync
CREATE OR REPLACE FUNCTION approve_vendor_v6(request_id UUID)
RETURNS VOID AS $$
DECLARE
    r RECORD;
BEGIN
    SELECT * INTO r FROM public.registration_requests WHERE id = request_id;

    -- 1. Create/Update Vendor Record
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

    -- 2. Update Request Status
    UPDATE public.registration_requests SET status = 'approved' WHERE id = request_id;

    -- 3. Broadcast Success
    INSERT INTO public.notifications (user_id, title, body, target_type)
    VALUES (r.owner_id, 'Node Activated!', 'Your kitchen is now live on the UNIV grid.', 'vendors');

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
