
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co'
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s'

const supabase = createClient(supabaseUrl, serviceKey)

async function checkTriggers() {
    const { data, error } = await supabase.rpc('get_table_triggers', { t_name: 'orders' });
    if (error) {
        console.log("Fallback search for triggers...");
        const { data: qData, error: qError } = await supabase.from('pg_trigger').select('tgname').limit(10);
        console.log("Triggers keys (if any):", qData);
    } else {
        console.log("Triggers:", data);
    }
}

checkTriggers();
