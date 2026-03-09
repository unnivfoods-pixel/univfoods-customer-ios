
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co'
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s'

const supabase = createClient(supabaseUrl, serviceKey)

async function checkCategories() {
    const { data, error } = await supabase.from('categories').select('*');
    if (error) {
        console.error("ERROR:", error.message);
    } else {
        console.log(`FOUND ${data.length} CATEGORIES:`);
        data.forEach(c => {
            console.log(`- ${c.name} (${c.is_active ? 'Active' : 'Inactive'}): ${c.image_url}`);
        });
    }
}

checkCategories();
