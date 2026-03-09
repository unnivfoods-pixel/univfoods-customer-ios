-- DESTROY ALL REGISTRATION DATA (Wiping for clean start)
TRUNCATE TABLE public.registration_requests;
TRUNCATE TABLE public.registrations;

-- Also ensure the columns are correct for the new manual workflow
ALTER TABLE public.registration_requests DROP COLUMN IF EXISTS message;
ALTER TABLE public.registration_requests ADD COLUMN IF NOT EXISTS message TEXT;
ALTER TABLE public.registration_requests ADD COLUMN IF NOT EXISTS type TEXT DEFAULT 'vendor';
