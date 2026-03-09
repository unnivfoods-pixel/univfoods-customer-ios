import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s';

const supabase = createClient(supabaseUrl, serviceRoleKey);

async function mergeIdentity8897868951() {
    console.log(">>> [MIGRATE] Hard Merging for phone: 8897868951...");
    const masterId = 'rrgtG3C1UHgIcBMMtfdSnF2Vxup2';
    const fragmentIds = ['sms_auth_8897868951', 'sms_auth_918897868951'];

    // 1. Migrate Orders
    const { error: oErr } = await supabase.from('orders').update({ customer_id: masterId }).in('customer_id', fragmentIds);
    if (oErr) console.error("ORDER MIGRATE ERROR:", oErr);
    else console.log("Orders migrated.");

    // 2. Migrate Addresses
    const { error: aErr } = await supabase.from('user_addresses').update({ user_id: masterId }).in('user_id', fragmentIds);
    if (aErr) console.error("ADDRESS MIGRATE ERROR:", aErr);
    else console.log("Addresses migrated.");

    // 3. Clean Profiles
    const { error: dErr } = await supabase.from('customer_profiles').delete().in('id', fragmentIds);
    if (dErr) console.error("PROFILE DELETE ERROR:", dErr);
    else console.log("Profiles cleaned.");

    console.log(">>> [SUCCESS] User 8897868951 consolidated to master account.");
}

mergeIdentity8897868951();
