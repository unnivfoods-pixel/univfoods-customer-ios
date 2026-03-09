
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co'
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s'

const supabase = createClient(supabaseUrl, serviceKey)

async function debugSystem() {
    console.log("--- VENDORS DATA ---");
    const { data: vendors, error: vError } = await supabase.from('vendors').select('*');
    if (vError) console.error("Vendors Error:", vError);
    else console.log(JSON.stringify(vendors, null, 2));

    console.log("\n--- ORDERS SCHEMA ---");
    const { data: orders, error: oError } = await supabase.from('orders').select('*').limit(1);
    if (oError) console.error("Orders Error:", oError);
    else if (orders && orders.length > 0) {
        console.log("Keys:", Object.keys(orders[0]));
        console.log("Sample Order:", JSON.stringify(orders[0], null, 2));
    }

    console.log("\n--- TESTING RPC: get_nearby_vendors_v4 ---");
    const { data: nearby, error: nError } = await supabase.rpc('get_nearby_vendors_v4', {
        p_lat: 9.5100,
        p_lng: 77.6300
    });
    if (nError) console.error("Nearby RPC Error:", nError);
    else console.log("Nearby Count:", nearby?.length);
}

debugSystem();
