import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s';

const supabase = createClient(supabaseUrl, serviceKey);

async function checkSchema() {
    const { data } = await supabase.from('legal_documents').select('*').limit(1);
    console.log("LEGAL_DOCS_COLS:" + (data && data.length > 0 ? Object.keys(data[0]).join(',') : 'EMPTY'));

    // Check if category or type exists
    const t1 = await supabase.from('legal_documents').select('type').limit(1);
    console.log("HAS_TYPE:" + (!t1.error));
    const t2 = await supabase.from('legal_documents').select('category').limit(1);
    console.log("HAS_CATEGORY:" + (!t2.error));
}
checkSchema();
