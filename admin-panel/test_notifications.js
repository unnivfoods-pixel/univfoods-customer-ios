import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
    'https://dxqcruvarqgnscenixzf.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s'
);

const MASTER_USER_ID = 'rrgtG3C1UHgIcBMMtfdSnF2Vxup2';

async function testNotificationFlow() {
    console.log('=== NOTIFICATION SYSTEM DIAGNOSTICS ===\n');

    // 1. Check last 3 notifications for master user
    const { data: notifs, error: ne } = await supabase
        .from('notifications')
        .select('*')
        .eq('user_id', MASTER_USER_ID)
        .order('created_at', { ascending: false })
        .limit(3);

    console.log('RECENT NOTIFS FOR MASTER USER:');
    if (ne) console.error('  Error:', ne.message);
    else notifs?.forEach(n => console.log(`  [${n.created_at?.slice(11, 19)}] ${n.title} | type: ${n.type}`));

    // 2. Test: Insert a live notification to trigger realtime
    console.log('\nINSERTING TEST NOTIFICATION...');
    const { data: ins, error: ie } = await supabase
        .from('notifications')
        .insert({
            user_id: MASTER_USER_ID,
            app_type: 'customer',
            title: '🔔 Realtime Test ' + new Date().toLocaleTimeString(),
            message: 'If this pops up on your phone, realtime notifications are WORKING!',
            type: 'order'
        })
        .select()
        .single();

    if (ie) console.error('INSERT FAILED:', ie.message);
    else console.log('INSERT SUCCESS - ID:', ins.id);
    console.log('Watch your phone for the notification NOW...');

    // 3. Check current order status
    const { data: order } = await supabase
        .from('orders')
        .select('id, status, order_status, customer_id')
        .eq('id', '3b08e900-78a6-489f-9cfe-ac1ef9bceaaa')
        .single();

    console.log('\nCURRENT ORDER STATUS:');
    console.log('  status:', order?.status, '| order_status:', order?.order_status);
    console.log('  customer_id:', order?.customer_id);
    console.log('  Matches master?', order?.customer_id === MASTER_USER_ID ? 'YES ✅' : 'NO ❌');
}

testNotificationFlow().catch(console.error);
