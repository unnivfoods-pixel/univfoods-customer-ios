-- 🛰️ VENDOR GEOLOCATION AUTOMATION
-- Ensures that vendors added via Admin Panel (lat/lng) are automatically synced to PostGIS Geography points.

-- 1. ADD COLUMNS IF MISSING (Safeguard)
ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;

-- 2. CREATE SYNC TRIGGER FUNCTION
CREATE OR REPLACE FUNCTION sync_vendor_geography()
RETURNS TRIGGER AS $$
BEGIN
    -- If latitude and longitude are provided, update the location point
    IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
        NEW.location := ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326)::geography;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. ATTACH TRIGGER
DROP TRIGGER IF EXISTS trg_sync_vendor_geography ON public.vendors;
CREATE TRIGGER trg_sync_vendor_geography
BEFORE INSERT OR UPDATE OF latitude, longitude ON public.vendors
FOR EACH ROW EXECUTE PROCEDURE sync_vendor_geography();

-- 4. UPDATE EXISTING VENDORS (If any have lat/lng but no location)
UPDATE public.vendors 
SET location = ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography
WHERE latitude IS NOT NULL AND longitude IS NOT NULL AND location IS NULL;
