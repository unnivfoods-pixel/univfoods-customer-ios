import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co'
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s'

const supabase = createClient(supabaseUrl, serviceKey)

async function linkVendorsToZone() {
    const { data: zones } = await supabase.from('delivery_zones').select('id').eq('active', true);
    if (!zones || zones.length === 0) {
        console.log("No active zones found.");
        return;
    }
    const zoneId = zones[0].id;
    console.log(`Linking all vendors to zone: ${zoneId}`);

    const { data: vendors } = await supabase.from('vendors').select('id');
    for (const v of vendors) {
        await supabase.from('vendors').update({ zone_id: zoneId }).eq('id', v.id);
    }
    console.log("All vendors linked to zone.");
}

linkVendorsToZone();
