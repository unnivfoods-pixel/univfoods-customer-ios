import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co'
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s'

const supabase = createClient(supabaseUrl, serviceKey)

async function verifyVendorCoords() {
    const { data: vendors, error } = await supabase.from('vendors').select('id, name, latitude, longitude');
    if (error) {
        console.error(error);
        return;
    }

    console.log("Current Vendor Coordinates in DB:");
    vendors.forEach(v => {
        console.log(`- ${v.name}: Lat=${v.latitude}, Lng=${v.longitude}`);
    });
}

verifyVendorCoords();
