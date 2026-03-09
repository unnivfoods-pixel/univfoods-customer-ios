import { createClient } from '@supabase/supabase-js';
const supabase = createClient('https://dxqcruvarqgnscenixzf.supabase.co', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s');

async function repair() {
    console.log("Repairing...");
    const { data: addresses } = await supabase.from('user_addresses').select('*');
    const { data: orders } = await supabase.from('orders').select('*');

    for (const o of orders) {
        const uid = o.user_id || o.customer_id;
        const oAddress = (o.delivery_address || o.address || '').trim();
        if (!uid || !oAddress) continue;

        console.log("Checking order:", o.id, "UID:", uid, "ADDR:", oAddress);

        // Match by UID and address string
        const addr = addresses.find(a =>
            a.user_id === uid &&
            a.address_line?.trim() === oAddress
        );

        if (addr) {
            console.log("FOUND MATCH! PIN:", addr.pincode, "PHONE:", addr.phone || addr.phone_number);
            const { error: updErr } = await supabase.from('orders').update({
                delivery_phone: (addr.phone || addr.phone_number || '').toString(),
                delivery_pincode: (addr.pincode || '').toString()
            }).eq('id', o.id);
            if (updErr) console.error("Update Error:", updErr);
        } else {
            console.log("No match found in addresses list of", addresses.length, "items");
        }
    }
    console.log("Repair finished.");
}
repair();
