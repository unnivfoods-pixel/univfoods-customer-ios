const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s';
const supabase = createClient(supabaseUrl, serviceKey);

async function inspectVendors() {
    console.log('Fetching one vendor to inspect schema...');
    const { data, error } = await supabase.from('vendors').select('*').limit(1);

    if (error) {
        console.error('FETCH ERROR:', error);
    } else if (data && data.length > 0) {
        console.log('EXISTING COLUMNS:', Object.keys(data[0]));
        console.log('SAMPLE DATA:', data[0]);
    } else {
        console.log('No vendors found. Table might be empty.');
    }
}

inspectVendors();
