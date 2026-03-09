import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co'
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s'

const supabase = createClient(supabaseUrl, serviceKey)

async function ensureVendorLive() {
    const { data: vendors } = await supabase.from('vendors').select('id, name');
    for (const v of vendors) {
        await supabase.from('vendors').update({
            is_verified: true,
            status: 'open',
            is_trending: true,
            is_top_rated: true,
            rating: 4.8
        }).eq('id', v.id);
    }
    console.log("All vendors are now verified and open.");
}

ensureVendorLive();
