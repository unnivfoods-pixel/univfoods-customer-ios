import { createClient } from '@supabase/supabase-js';
const supabase = createClient('https://dxqcruvarqgnscenixzf.supabase.co', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s');

async function repair() {
    console.log("Repairing profiles from user_addresses...");

    // Get all user addresses to find any phone/pincode we can use
    const { data: addresses, error: addrErr } = await supabase.from('user_addresses').select('*');
    const { data: profiles, error: profErr } = await supabase.from('customer_profiles').select('*');

    for (const prof of profiles) {
        const addr = addresses.find(a => a.user_id === prof.id && (a.phone || a.phone_number));
        if (addr) {
            const phone = (addr.phone || addr.phone_number).toString();
            console.log("Repairing Profile", prof.id, "Phone:", phone);
            await supabase.from('customer_profiles').update({ phone }).eq('id', prof.id);
        }
    }

    console.log("Repairing Orders from matching addresses...");
    const { data: orders, error: ordErr } = await supabase.from('orders').select('*');
    for (const o of orders) {
        const uid = o.customer_id || o.user_id;
        if (!uid) continue;

        // Match by UID and address_line string
        const addr = addresses.find(a => a.user_id === uid && a.address_line === (o.delivery_address || o.address));
        if (addr) {
            console.log("Repairing Order", o.id, "PIN:", addr.pincode, "PHONE:", addr.phone || addr.phone_number);
            await supabase.from('orders').update({
                delivery_phone: (addr.phone || addr.phone_number).toString(),
                delivery_pincode: addr.pincode.toString()
            }).eq('id', o.id);
        }
    }
    console.log("Done.");
}
repair();
