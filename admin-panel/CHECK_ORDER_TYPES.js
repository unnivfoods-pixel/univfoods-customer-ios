
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co'
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s'

const supabase = createClient(supabaseUrl, serviceKey)

async function checkTypes() {
    const { data, error } = await supabase.rpc('get_table_column_types', { t_name: 'orders' });
    if (error) {
        console.log("No column types helper, using direct query...");
        // This is a common pattern to get types in postgres if no RPC exists
        const { data: cols, error: cErr } = await supabase.from('pg_attribute')
            .select('attname, atttypid')
            .eq('attrelid', "'public.orders'::regclass")
            .eq('attisdropped', false);
        // Better yet, just use a query that definitely works
        const { data: info, error: iErr } = await supabase.rpc('debug_sql', {
            p_query: "SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'orders'"
        });
        if (iErr) console.error(iErr);
        else console.log(info);
    } else {
        console.log(data);
    }
}

checkTypes();
