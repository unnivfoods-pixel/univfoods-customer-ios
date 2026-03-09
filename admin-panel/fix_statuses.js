import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s';

const supabase = createClient(supabaseUrl, serviceRoleKey);

async function fixStatuses() {
    console.log(">>> [FIX] Normalizing Order Statuses to UPPERCASE...");

    const { data: orders, error } = await supabase.from('orders').select('id, status');
    if (error) {
        console.error("FETCH ERROR:", error);
        return;
    }

    for (const order of orders) {
        if (order.status !== order.status.toUpperCase()) {
            console.log(`Updating ${order.id}: ${order.status} -> ${order.status.toUpperCase()}`);
            await supabase.from('orders').update({ status: order.status.toUpperCase() }).eq('id', order.id);
        }
    }
    console.log(">>> [FIX] Statuses normalized.");
}

fixStatuses();
