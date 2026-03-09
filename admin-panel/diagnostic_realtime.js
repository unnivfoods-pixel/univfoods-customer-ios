import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s';

const supabase = createClient(supabaseUrl, serviceRoleKey);

async function checkRealtime() {
    console.log(">>> [DIAGNOSTIC] Checking Realtime Configuration...");

    // 1. Check if we can see the orders
    const { data: orders, error } = await supabase.from('orders').select('id, status').limit(5);
    if (error) {
        console.error("ERROR FETCHING ORDERS:", error);
        return;
    }
    console.log("LATEST ORDERS:", orders);

    // 2. Try to update a dummy field to trigger realtime
    if (orders.length > 0) {
        const targetId = orders[0].id;
        console.log(`ATTEMPTING TRIGGER UPDATE ON: ${targetId}`);
        const { error: upError } = await supabase.from('orders').update({ updated_at: new Date().toISOString() }).eq('id', targetId);
        if (upError) console.error("UPDATE ERROR:", upError);
        else console.log("UPDATE SUCCESS! Realtime event should have fired.");
    }

    // 3. Check for publication
    console.log("Checking Publication Status (requires exec_sql, skipping raw SQL check)");
}

checkRealtime();
