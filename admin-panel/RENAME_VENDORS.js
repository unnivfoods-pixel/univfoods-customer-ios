import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co'
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s'

const supabase = createClient(supabaseUrl, serviceKey)

async function renameAndFixVendors() {
    const { data: vendors, error } = await supabase.from('vendors').select('*');
    if (error) {
        console.error(error);
        return;
    }

    const lat = 9.5093;
    const lng = 77.6322;

    for (let i = 0; i < vendors.length; i++) {
        const v = vendors[i];
        let newName = v.name;
        if (i === 0) newName = "Srivilliputhur Curry Point";
        else if (i === 1) newName = "UNIV Special Curry";

        console.log(`Updating ${v.name} -> ${newName}...`);
        const { error: updateError } = await supabase
            .from('vendors')
            .update({
                name: newName,
                address: "Main Roat, Srivilliputhur",
                latitude: lat + (i * 0.001), // Slighly offset so they aren't exactly on top of each other
                longitude: lng + (i * 0.001),
                is_verified: true,
                status: 'open',
                is_trending: true,
                is_top_rated: true,
                rating: 4.8,
                delivery_time: "25 min"
            })
            .eq('id', v.id);

        if (updateError) console.error(`Failed to update ${v.name}:`, updateError.message);
        else console.log(`Updated ${v.name} successfully.`);
    }
}

renameAndFixVendors();
