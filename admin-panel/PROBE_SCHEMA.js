
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co'
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s'

const supabase = createClient(supabaseUrl, serviceKey)

async function getFullSchema() {
    const { data, error } = await supabase.rpc('get_table_columns', { table_name: 'orders' });

    if (error) {
        // Fallback to direct query if RPC doesn't exist
        const { data: cols, error: err2 } = await supabase
            .from('orders')
            .select('*')
            .limit(0);

        if (err2) {
            // Try fetching from information_schema via a trick or another way
            console.log("Could not get columns directly. Error:", err2.message);
        } else {
            console.log("Columns from select limit 0:", Object.keys(cols?.[0] || {}));
        }
    } else {
        console.log("Columns from RPC:", data);
    }
}

// Another way to check columns: try to insert a garbage column and see the error
async function probeColumns() {
    const { error } = await supabase.from('orders').insert({ probe_column: 1 });
    console.log("Probe Error:", error?.message);
}

probeColumns();
