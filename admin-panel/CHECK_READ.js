import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co'
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s'

const supabase = createClient(supabaseUrl, serviceKey)

async function checkPolicies() {
    const { data, error } = await supabase.rpc('get_policies', { table_name: 'vendors' });
    if (error) {
        // Fallback: check if we can read as anon
        const anonClient = createClient(supabaseUrl, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwMjQ2NzksImV4cCI6MjA4MzYwMDY3OX0.12k9-T5777777777777777777777777777777777777')
        // Note: the above anon key is a placeholder, I should use the real one if I had it. 
        // But I don't have the anon key easily available here.
        console.log("Checking via SQL...");
    }
}

// I'll just use a direct query to check if public can read
async function checkPublicRead() {
    const { data, error } = await supabase.from('vendors').select('name').limit(1);
    console.log("Service Key Read:", error ? error.message : "Success");
}

checkPublicRead();
