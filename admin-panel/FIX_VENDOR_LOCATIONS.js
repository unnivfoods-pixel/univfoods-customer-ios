import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co'
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s'

const supabase = createClient(supabaseUrl, serviceKey)

async function fixVendorLocations() {
    console.log("Fetching vendors...");
    const { data: vendors, error } = await supabase.from('vendors').select('id, name');

    if (error) {
        console.error(error);
        return;
    }

    console.log(`Found ${vendors.length} vendors.`);

    // Srivilliputhur Center approx
    const lat = 9.5093;
    const lng = 77.6322;

    for (const vendor of vendors) {
        console.log(`Updating ${vendor.name} to Srivilliputhur coords...`);
        const { error: updateError } = await supabase
            .from('vendors')
            .update({
                latitude: lat,
                longitude: lng
            })
            .eq('id', vendor.id);

        if (updateError) console.error(`Failed to update ${vendor.name}:`, updateError.message);
        else console.log(`Updated ${vendor.name} successfully.`);
    }

    // Also update zones if necessary?
    // Let's just focus on vendors first.
}

fixVendorLocations();
