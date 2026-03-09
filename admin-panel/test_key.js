import { createClient } from '@supabase/supabase-js';

const supabase = createClient('https://dxqcruvarqgnscenixzf.supabase.co', 'eyJhbGciOiJIUzI1NiIsInR5cCI6ImpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s');

async function testKey() {
    const { data, error } = await supabase.from('vendors').select('*').limit(1);
    if (error) {
        console.error("KEY TEST FAILED:", error);
    } else {
        console.log("KEY TEST SUCCESS. Vendors detected.");
    }
}

testKey();
