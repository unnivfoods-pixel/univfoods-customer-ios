
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co'
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s'

const supabase = createClient(supabaseUrl, serviceKey)

async function debugOrders() {
    const { data, error } = await supabase.rpc('get_table_info', { p_table_name: 'orders' });
    if (error) {
        // Fallback: try to just select and see what types we get back in JSON
        const { data: rows } = await supabase.from('orders').select('*').limit(1);
        console.log("ORDERS DATA TYPES (JSON):");
        console.log(JSON.stringify(rows));
    } else {
        console.log("ORDERS INFO:");
        console.log(data);
    }
}

debugOrders();
