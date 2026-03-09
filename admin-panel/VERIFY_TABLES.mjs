import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s';

const supabase = createClient(supabaseUrl, serviceKey);

async function check() {
    console.log(">>> Checking Tables Existence...");
    const tables = ['faqs', 'legal_documents', 'system_settings', 'partner_applications', 'safety_reports'];

    for (const table of tables) {
        const { error } = await supabase.from(table).select('*').limit(1);
        if (error) {
            console.log(`[X] Table '${table}' ERROR: ${error.message} (Code: ${error.code})`);
        } else {
            console.log(`[OK] Table '${table}' EXISTS`);
        }
    }
}

check();
