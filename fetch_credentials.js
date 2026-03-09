
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co'
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s'

const supabase = createClient(supabaseUrl, serviceKey)

async function getVendors() {
    console.log("--- VENDORS ---");
    const { data: vendors, error: vError } = await supabase.from('vendors').select('name, email, phone');
    if (vError) console.error(vError);
    else console.table(vendors);

    console.log("\n--- REGISTRATION REQUESTS ---");
    const { data: requests, error: rError } = await supabase.from('registration_requests').select('name, email, type, status');
    if (rError) console.error(rError);
    else console.table(requests);

    console.log("\n--- AUTH USERS (Emails only) ---");
    // We can't query auth.users directly without RPC, but we can check the profiles or common emails
}

getVendors();
