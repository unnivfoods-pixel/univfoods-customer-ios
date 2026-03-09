import { createClient } from '@supabase/supabase-js';
import fs from 'fs';

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6ImpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s';

const supabase = createClient(supabaseUrl, serviceKey);

async function run() {
    const sqlPath = '../MASTER_REALTIME_CONSOLIDATED.sql';
    console.log("Reading SQL from:", sqlPath);
    const sql = fs.readFileSync(sqlPath, 'utf8');

    console.log("Executing SQL...");
    // Try different common RPC names and parameter names found in the project
    const rpcAttempts = [
        { name: 'exec_sql', param: 'sql' },
        { name: 'exec_sql', param: 'sql_query' },
        { name: 'exec_sql', param: 'query' },
        { name: 'run_sql', param: 'sql' },
        { name: 'execute_sql', param: 'sql' }
    ];

    for (const attempt of rpcAttempts) {
        console.log(`Trying ${attempt.name}(${attempt.param})...`);
        const { data, error } = await supabase.rpc(attempt.name, { [attempt.param]: sql });
        if (!error) {
            console.log(`SUCCESS with ${attempt.name}(${attempt.param})!`);
            console.log("Result:", data);
            return;
        }
        console.log(`Failed ${attempt.name}(${attempt.param}):`, error.message);
    }
    console.error("Could not find a workable RPC via supabase-js. You may need to run the SQL manually in the Supabase Dashboard.");
}

run();
