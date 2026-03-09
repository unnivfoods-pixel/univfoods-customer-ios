import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s';

const supabase = createClient(supabaseUrl, serviceKey);

async function checkSchema() {
    console.log("Checking legal_documents table...");
    try {
        const { data, error } = await supabase.from('legal_documents').select('*').limit(1);
        if (error) {
            console.error("Error fetching legal_documents:", error);
        } else {
            console.log("Table exists. Records found:", data.length);
            if (data.length > 0) {
                console.log("Columns found:", Object.keys(data[0]));
            } else {
                console.log("No records found to determine columns via select *.");
                // Try a known column from the other schema
                const { error: colError } = await supabase.from('legal_documents').select('type').limit(1);
                if (colError) {
                    console.log("Column 'type' NOT found. Error:", colError.message);
                } else {
                    console.log("Column 'type' EXISTS.");
                }
            }
        }

        const { data: accData, error: accError } = await supabase.from('legal_acceptance').select('*').limit(1);
        if (accError) {
            console.error("Error fetching legal_acceptance:", accError.message);
        } else {
            console.log("Table 'legal_acceptance' exists.");
        }
    } catch (e) {
        console.error("Exec error:", e);
    }
}

checkSchema();
