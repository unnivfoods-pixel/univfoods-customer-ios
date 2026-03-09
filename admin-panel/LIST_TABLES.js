import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co'
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s'

const supabase = createClient(supabaseUrl, serviceKey)

async function listTables() {
    // We try to fetch from a few likely candidates
    const tables = ['vendors', 'orders', 'delivery_riders', 'delivery_zones', 'service_zones', 'zones', 'categories', 'products'];
    for (const table of tables) {
        const { error } = await supabase.from(table).select('*').limit(1);
        if (!error) {
            console.log(`Table exists: ${table}`);
        } else if (error.code !== 'PGRST204' && error.code !== '42P01') {
            // 42P01 is "relation does not exist"
            console.log(`Table candidate ${table} gave error ${error.code}: ${error.message}`);
        }
    }
}

listTables();
