
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co'
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s'

const supabase = createClient(supabaseUrl, serviceKey)

async function checkSchema() {
    console.log("Checking banners table schema...");
    const { data, error } = await supabase.from('banners').select('*').limit(1);

    if (error) {
        console.error("Error fetching banners:", error);
    } else {
        console.log("Banner keys:", data.length > 0 ? Object.keys(data[0]) : "No data to check keys");
    }

    // Try to get column names from information_schema if possible via rpc or just a raw query?
    // We can't do raw query easily.
    // But we can try to insert a dummy record and see the error.
}

checkSchema();
