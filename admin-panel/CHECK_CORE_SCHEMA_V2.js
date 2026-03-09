
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co'
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s'

const supabase = createClient(supabaseUrl, serviceKey)

async function checkSchema() {
    const { data: pData } = await supabase.from('products').select('*').limit(1);
    if (pData && pData.length > 0) {
        console.log("PRODUCTS_START");
        Object.keys(pData[0]).forEach(k => console.log("P:" + k));
        console.log("PRODUCTS_END");
    }

    const { data: vData } = await supabase.from('vendors').select('*').limit(1);
    if (vData && vData.length > 0) {
        console.log("VENDORS_START");
        Object.keys(vData[0]).forEach(k => console.log("V:" + k));
        console.log("VENDORS_END");
    }
}

checkSchema();
