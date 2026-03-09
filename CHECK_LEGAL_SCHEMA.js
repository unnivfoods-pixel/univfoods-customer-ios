const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s';

const supabase = createClient(supabaseUrl, serviceKey);

async function checkSchema() {
    console.log("Checking legal_documents table...");
    try {
        const { data, error } = await supabase.from('legal_documents').select('*').limit(1);
        if (error) {
            console.error("Error fetching legal_documents:", error);
            if (error.message.includes('does not exist')) {
                console.log("Table 'legal_documents' does not exist.");
            }
        } else {
            console.log("Table exists. Columns found in first record (if any):", data.length > 0 ? Object.keys(data[0]) : "No records yet.");

            // Try to fetch column names via RPC or a fake query with error
            const { error: colError } = await supabase.from('legal_documents').select('non_existent_column');
            if (colError) {
                console.log("Column check hint:", colError.message);
            }
        }

        const { data: accData, error: accError } = await supabase.from('legal_acceptance').select('*').limit(1);
        if (accError) {
            console.error("Error fetching legal_acceptance:", accError);
        } else {
            console.log("Table 'legal_acceptance' exists.");
        }
    } catch (e) {
        console.error("Exec error:", e);
    }
}

checkSchema();
