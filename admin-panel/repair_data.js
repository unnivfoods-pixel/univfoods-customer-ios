import { createClient } from '@supabase/supabase-js';
const supabase = createClient('https://dxqcruvarqgnscenixzf.supabase.co', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s');

async function repair(uid) {
    console.log("Repairing profiles from user_addresses...");

    // Get all user addresses to find any phone/pincode we can use
    const { data: addresses, error: addrErr } = await supabase.from('user_addresses').select('*');
    if (addrErr) {
        console.error(addrErr);
        return;
    }

    const { data: profiles, error: profErr } = await supabase.from('customer_profiles').select('*');
    if (profErr) {
        console.error(profErr);
        return;
    }

    for (const prof of profiles) {
        // Find any address for this user that has a phone
        const addr = addresses.find(a => a.user_id === prof.id && (a.phone || a.phone_number));
        if (addr) {
            const phone = (addr.phone || addr.phone_number).toString();
            console.log("Found phone", phone, "for user", prof.id);
            await supabase.from('customer_profiles').update({ phone }).eq('id', prof.id);
        }
    }

    // Now HEAL the orders too!
    console.log("Healing orders with missing delivery_phone...");
    const { data: orders, error: ordErr } = await supabase.from('orders').select('*');
    for (const o of orders) {
        const uid = o.customer_id || o.user_id;
        if (!uid) continue;
        const addr = addresses.find(a => a.user_id === uid && a.address_line === o.delivery_address);
        if (addr) {
            console.log("Order", o.id, "found address match. Updating PIN:", addr.pincode, "Phone:", addr.phone || addr.phone_number);
            await supabase.from('orders').update({
                delivery_phone: addr.phone || addr.phone_number,
                delivery_pincode: addr.pincode
            }).eq('id', o.id);
        }
    }
    console.log("Done.");
}
repair();
