import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co'
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s'

const supabase = createClient(supabaseUrl, serviceKey)

async function checkSrivilliputhurVendor() {
    const { data, error } = await supabase
        .from('vendors')
        .select('*')
        .ilike('name', '%Srivilliputhur%');

    if (error) {
        console.error(error);
    } else {
        console.log("Matching Vendors:", JSON.stringify(data, null, 2));
    }
}

checkSrivilliputhurVendor();
