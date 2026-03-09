import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6ImpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s';

const supabase = createClient(supabaseUrl, serviceKey);

async function testInsert() {
    const testUserId = 'YUvuMkPDWHayJSIcfsz32WgICF73'; // From latest orders
    const { data, error } = await supabase.from('notifications').insert({
        user_id: testUserId,
        user_role: 'customer',
        title: '🧪 Manual Test Notif',
        message: 'This is a manual test to check user_id persistence.',
        body: 'This is a manual test to check user_id persistence.',
        type: 'TEST'
    }).select();

    if (error) {
        console.log("Insert Error:", error.message);
    } else {
        console.log("Insert Success:", data);
    }
}
testInsert();
