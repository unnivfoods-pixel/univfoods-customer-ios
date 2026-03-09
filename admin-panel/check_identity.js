import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s';

const supabase = createClient(supabaseUrl, serviceRoleKey);

async function checkIdentity() {
    console.log(">>> [IDENTITY CHECK] Analyzing user IDs and orders...");

    // 1. Get all customer profiles
    const { data: profiles, error: pError } = await supabase.from('customer_profiles').select('*');
    if (pError) {
        console.error("PROFILES FETCH ERROR:", pError);
        return;
    }
    console.log(`TOTAL PROFILES: ${profiles.length}`);
    console.table(profiles.slice(0, 10));

    // 2. Get all orders and their customer_ids
    const { data: orders, error: oError } = await supabase.from('orders').select('id, customer_id, status, created_at').order('created_at', { ascending: false }).limit(20);
    if (oError) {
        console.error("ORDERS FETCH ERROR:", oError);
        return;
    }
    console.log(`LATEST 20 ORDERS:`);
    console.table(orders);

    // 3. Count orders per customer_id
    const stats = {};
    const { data: allOrders } = await supabase.from('orders').select('customer_id');
    allOrders?.forEach(o => {
        stats[o.customer_id] = (stats[o.customer_id] || 0) + 1;
    });
    console.log("ORDER COUNTS PER CUSTOMER_ID:", stats);
}

checkIdentity();
