import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co'
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s'

const supabase = createClient(supabaseUrl, serviceKey)

async function finishVendorSetup() {
    const { data: vendors, error } = await supabase.from('vendors').select('id');
    if (error) return;

    for (const v of vendors) {
        await supabase.from('vendors').update({
            cuisine_type: 'Curry, North Indian, South Indian',
            tags: ['trending', 'top rated', 'fast delivery', 'pure veg'],
            is_verified: true,
            status: 'open',
            zone_id: null // Remove zone restriction for now to be safe
        }).eq('id', v.id);
    }
    console.log("Vendors updated with tags and zone cleared.");
}

finishVendorSetup();
