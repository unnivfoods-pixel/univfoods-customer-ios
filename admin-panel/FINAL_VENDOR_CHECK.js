import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co'
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s'

const supabase = createClient(supabaseUrl, serviceKey)

async function finalSrivilliputhurCheck() {
    const { data: vendors, error } = await supabase.from('vendors').select('*');
    if (error) {
        console.error(error);
        return;
    }

    vendors.forEach(v => {
        console.log(`[${v.name}] Coords: ${v.latitude}, ${v.longitude} | Verified: ${v.is_verified} | Status: ${v.status} | Zone: ${v.zone_id}`);
    });
}

finalSrivilliputhurCheck();
