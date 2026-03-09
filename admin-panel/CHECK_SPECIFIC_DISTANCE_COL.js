import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co'
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s'

const supabase = createClient(supabaseUrl, serviceKey)

async function checkSpecificColumn() {
    const { data, error } = await supabase.from('orders').select('order_distance_km').limit(1);
    if (error) {
        if (error.code === 'PGRST204' || error.message.includes('column')) {
            console.log("order_distance_km column: MISSING");
        } else {
            console.error("Error:", error);
        }
    } else {
        console.log("order_distance_km column: EXISTS");
    }
}

checkSpecificColumn();
