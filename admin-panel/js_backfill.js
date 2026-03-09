import { createClient } from '@supabase/supabase-js';
const supabase = createClient('https://dxqcruvarqgnscenixzf.supabase.co', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s');

async function backfill() {
    console.log("Fetching orders...");
    const { data: orders, error: orderErr } = await supabase.from('orders').select('user_id, customer_id, customer_name_snapshot, customer_phone_snapshot');
    if (orderErr) {
        console.error(orderErr);
        return;
    }

    console.log("Found", orders.length, "orders. Processing unique users...");
    const userMap = new Map();
    for (const o of orders) {
        const uid = o.customer_id || o.user_id;
        if (!uid) continue;
        if (!userMap.has(uid)) {
            userMap.set(uid, {
                id: uid,
                full_name: o.customer_name_snapshot || '',
                phone: o.customer_phone_snapshot || ''
            });
        }
    }

    const profiles = Array.from(userMap.values());
    console.log("Unique profiles to upsert:", profiles.length);

    for (const p of profiles) {
        console.log("Upserting:", p.id);
        const { error } = await supabase.from('customer_profiles').upsert(p);
        if (error) console.error("Error upserting", p.id, error);
    }
    console.log("Done.");
}
backfill();
