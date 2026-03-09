
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co'
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s'

const supabase = createClient(supabaseUrl, serviceKey)

async function checkCategoriesSchema() {
    // Insert a temp category to see columns, then delete it
    const tempName = "TEMP_" + Date.now();
    const { data, error } = await supabase.from('categories').insert({ name: tempName }).select();
    if (error) {
        console.error("INSERT ERROR (maybe due to required fields):", error.message);
        // Try to fetch one even if empty to get schema? No, that doesn't work if empty.
        // We can use RPC or generic query to get column names if we had permissions, 
        // but easier to just guess or look at code.
    } else {
        console.log("COLUMNS:", Object.keys(data[0]).join(", "));
        await supabase.from('categories').delete().eq('name', tempName);
    }
}

checkCategoriesSchema();
