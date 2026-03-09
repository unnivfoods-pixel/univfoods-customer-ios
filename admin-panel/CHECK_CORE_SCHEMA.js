
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co'
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s'

const supabase = createClient(supabaseUrl, serviceKey)

async function checkSchema() {
    console.log("Checking products table...");
    const { data: pData, error: pError } = await supabase.from('products').select('*').limit(1);
    if (!pError && pData.length > 0) {
        console.log("PRODUCTS COLUMNS:", Object.keys(pData[0]).join(", "));
    } else {
        console.log("PRODUCTS ERROR or EMPTY:", pError?.message);
    }

    console.log("Checking vendors table...");
    const { data: vData, error: vError } = await supabase.from('vendors').select('*').limit(1);
    if (!vError && vData.length > 0) {
        console.log("VENDORS COLUMNS:", Object.keys(vData[0]).join(", "));
    } else {
        console.log("VENDORS ERROR or EMPTY:", vError?.message);
    }
}

checkSchema();
