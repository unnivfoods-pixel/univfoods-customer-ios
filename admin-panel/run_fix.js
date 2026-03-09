import { createClient } from '@supabase/supabase-js';
import fs from 'fs';
import path from 'path';

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6ImpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s';

const supabase = createClient(supabaseUrl, serviceKey);

async function run() {
    const sqlPath = '../ULTIMATE_NOTIFICATION_FIX_V71.sql';
    console.log("Reading SQL from:", sqlPath);
    const sql = fs.readFileSync(sqlPath, 'utf8');

    console.log("Executing SQL...");
    // Try different common RPC names
    const rpcs = ['exec_sql', 'run_sql', 'execute_sql'];
    const params = ['sql', 'query', 'p_query'];

    for (const rpc of rpcs) {
        for (const p of params) {
            console.log(`Trying ${rpc}(${p})...`);
            const { data, error } = await supabase.rpc(rpc, { [p]: sql });
            if (!error) {
                console.log(`SUCCESS with ${rpc}(${p})!`);
                return;
            }
            console.log(`Failed ${rpc}(${p}):`, error.message);
        }
    }
    console.error("Could not find a workable RPC via supabase-js.");
}

run();
