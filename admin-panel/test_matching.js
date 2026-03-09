import { createClient } from '@supabase/supabase-js';
const supabase = createClient('https://dxqcruvarqgnscenixzf.supabase.co', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s');

async function testMatch() {
    const { data: o } = await supabase.from('orders').select('*').eq('id', '24c074cd-fc11-42b2-9958-cc592b845fd2').maybeSingle();
    const { data: a } = await supabase.from('user_addresses').select('*').limit(10);

    console.log("Order UID:", o.user_id, "Len:", o.user_id?.length);
    console.log("Order Address:", o.delivery_address, "Len:", o.delivery_address?.length);

    for (const addr of a) {
        console.log("Addr UID:", addr.user_id, "Len:", addr.user_id?.length);
        console.log("Addr Line:", addr.address_line, "Len:", addr.address_line?.length);
        console.log("UID Match:", addr.user_id === o.user_id);
        console.log("Addr Match:", addr.address_line === o.delivery_address);
    }
}
testMatch();
