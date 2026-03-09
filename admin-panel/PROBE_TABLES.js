import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co'
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6ImpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s'

const supabase = createClient(supabaseUrl, serviceKey)

async function listTables() {
    // We can't query information_schema directly via PostgREST,
    // but we can try to find an RPC or just try common table names.
    const tables = ['vendors', 'orders', 'customer_profiles', 'users', 'delivery_riders', 'notifications', 'faqs', 'menu_items', 'categories'];

    for (const table of tables) {
        const { error } = await supabase.from(table).select('*').limit(0);
        if (error) {
            console.log(`[ABSENT] ${table}: ${error.message}`);
        } else {
            console.log(`[EXISTS] ${table}`);
        }
    }
}

listTables();
