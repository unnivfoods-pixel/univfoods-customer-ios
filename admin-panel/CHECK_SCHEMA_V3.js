
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co'
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s'

const supabase = createClient(supabaseUrl, serviceKey)

async function checkSchema() {
    const { data } = await supabase.from('banners').select('*').limit(1);
    if (data && data.length > 0) {
        console.log("COLUMNS_START");
        Object.keys(data[0]).forEach(k => console.log(k));
        console.log("COLUMNS_END");
    } else {
        // Try to insert a dummy and see the error?
        // Let's try to get one from another table to check connection
        const { data: catData } = await supabase.from('categories').select('*').limit(1);
        if (catData && catData.length > 0) {
            console.log("CAT_COLUMNS_START");
            Object.keys(catData[0]).forEach(k => console.log(k));
            console.log("CAT_COLUMNS_END");
        }
    }
}

checkSchema();
