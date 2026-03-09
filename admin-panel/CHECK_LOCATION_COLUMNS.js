import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co'
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s'

const supabase = createClient(supabaseUrl, serviceKey)

async function checkSchema() {
    const tables = ['vendors', 'orders', 'delivery_riders'];
    for (const table of tables) {
        console.log(`--- Checking ${table} ---`);
        const { data, error } = await supabase.from(table).select('*').limit(1);
        if (error) {
            console.error(`Error checking ${table}:`, error.message);
            continue;
        }
        if (data.length > 0) {
            const cols = Object.keys(data[0]);
            console.log(`Columns in ${table}:`);
            cols.forEach(c => {
                if (c.includes('lat') || c.includes('lng') || c.includes('location') || c.includes('address')) {
                    console.log(` - ${c}`);
                }
            });
        } else {
            console.log(`No data in ${table} to check columns.`);
        }
    }
}

checkSchema();
