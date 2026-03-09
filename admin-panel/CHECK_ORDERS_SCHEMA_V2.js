
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co'
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s'

const supabase = createClient(supabaseUrl, serviceKey)

async function checkOrdersSchema() {
    const { data } = await supabase.from('orders').select('*').limit(1);
    if (data && data.length > 0) {
        console.log("ORDERS_COLUMNS_START");
        Object.keys(data[0]).forEach(k => console.log(k));
        console.log("ORDERS_COLUMNS_END");
    } else {
        console.log("No orders found.");
    }
}

checkOrdersSchema();
