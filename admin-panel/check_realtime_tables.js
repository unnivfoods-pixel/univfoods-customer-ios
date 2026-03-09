import { createClient } from '@supabase/supabase-js';

const supabase = createClient('https://dxqcruvarqgnscenixzf.supabase.co', 'eyJhbGciOiJIUzI1NiIsInR5cCI6ImpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s');

async function checkRealtime() {
    console.log("Checking Publication Tables...");
    // We can query pg_publication_tables directly with service role key if exposed via PostgREST,
    // but usually internal pg tables are not exposed.
    // Let's try to find an RPC that works or just run a direct query on a table to see if we have access.

    // Actually, I'll try to use the rpc 'exec_sql' again but with the service role key.
    const { data, error } = await supabase.rpc('exec_sql', {
        sql: "SELECT tablename FROM pg_publication_tables WHERE pubname = 'supabase_realtime';"
    });

    if (error) {
        console.error("RPC exec_sql failed even with service key:", error);
    } else {
        console.log("Realtime Tables:", data);
    }
}

checkRealtime();
