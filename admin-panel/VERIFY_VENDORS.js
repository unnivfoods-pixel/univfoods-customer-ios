import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co'
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s'

const supabase = createClient(supabaseUrl, serviceKey)

async function verifyAndOpenVendors() {
    const { data: vendors, error } = await supabase.from('vendors').select('*');
    if (error) {
        console.error(error);
        return;
    }

    for (const vendor of vendors) {
        console.log(`Verifying and Opening ${vendor.name}...`);
        const { error: updateError } = await supabase
            .from('vendors')
            .update({
                is_verified: true,
                status: 'open',
                is_trending: true,
                is_top_rated: true,
                rating: 4.8
            })
            .eq('id', vendor.id);

        if (updateError) console.error(`Failed to update ${vendor.name}:`, updateError.message);
        else console.log(`Updated ${vendor.name} successfully.`);
    }
}

verifyAndOpenVendors();
