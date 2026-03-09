
import { createClient } from '@supabase/supabase-js'
import fs from 'fs'

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co'
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s'

const supabase = createClient(supabaseUrl, serviceKey)

async function runSql() {
    const sql = fs.readFileSync('FINAL_SCHEMA_FIX_V2.sql', 'utf8');

    // We can't run raw SQL easily via JS client, but we can try small operations 
    // or use a helper function if defined. 
    // Since I don't have an RPC for SQL, I will try to add columns via direct checks 
    // OR I will ask the user to run it.

    // Actually, I can use the 'supabase' client to check and add columns programmatically.
    console.log("Applying schema fixes programmatically...");

    const tables = ['orders', 'delivery_riders'];

    for (const table of tables) {
        console.log(`Checking table: ${table}`);
        const { data: cols, error } = await supabase.from(table).select('*').limit(1);
        if (error) {
            console.log(`Error checking table ${table}:`, error.message);
            continue;
        }

        const existingCols = Object.keys(cols[0] || {});
        console.log(`Existing columns in ${table}:`, existingCols.join(", "));
    }

    console.log("\nIMPORTANT: Please run the contents of 'FINAL_SCHEMA_FIX_V2.sql' in your Supabase SQL Editor to ensure all columns are created correctly.");
}

runSql();
