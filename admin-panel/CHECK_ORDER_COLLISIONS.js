
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co'
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s'

const supabase = createClient(supabaseUrl, serviceKey)

async function checkCollision() {
    const { data, error } = await supabase.from('orders').select('*').limit(1);
    if (error) {
        console.error("Error fetching orders:", error);
        return;
    }
    if (data && data.length > 0) {
        console.log("ORDER COLUMNS:", Object.keys(data[0]));
    } else {
        console.log("No orders found");
    }
}

checkCollision();
