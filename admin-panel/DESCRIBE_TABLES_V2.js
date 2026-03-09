import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co'
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s'

const supabase = createClient(supabaseUrl, serviceKey)

async function describeTable(tableName) {
    const { data, error } = await supabase.from(tableName).select('*').limit(1);
    if (error) {
        console.error(`Error fetching from ${tableName}:`, error);
        return;
    }
    if (data && data.length > 0) {
        console.log(`\nColumns for ${tableName}:`);
        console.log(Object.keys(data[0]).join(', '));
    } else {
        console.log(`\nTable ${tableName} is empty, could not determine columns via SELECT.`);
        // Try to get columns via a more direct method if possible, but SELECT 1 is easiest for now
    }
}

async function run() {
    await describeTable('vendors');
    await describeTable('user_addresses');
}

run();
