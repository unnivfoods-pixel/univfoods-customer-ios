import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co'
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s'

const supabase = createClient(supabaseUrl, serviceKey)

async function cleanBadAddresses() {
    // List all addresses
    const { data: addresses, error } = await supabase.from('user_addresses').select('*');
    if (error) {
        console.error(error);
        return;
    }

    console.log(`Found ${addresses.length} addresses.`);

    // Delete addresses that are suspiciously far from Srivilliputhur (Lat 9.5)
    // Bangalore is Lat ~12.9
    const badAddresses = addresses.filter(a => a.latitude > 11.0);

    for (const addr of badAddresses) {
        console.log(`Deleting bad address: ${addr.address_line} (${addr.latitude}, ${addr.longitude})`);
        await supabase.from('user_addresses').delete().eq('id', addr.id);
    }

    console.log("Cleanup complete.");
}

cleanBadAddresses();
