const https = require('https');

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s';

const tableName = 'notifications';

const targets = ['test_string', 'rrgtG3C1UHgIcBMMtfdSnFp7pL43']; // rrgt ID might be the user

async function send(userId) {
    const data = JSON.stringify({
        user_id: userId,
        title: '🔔 System Verified',
        message: 'Your notification system is now LIVE and working.',
        body: 'Realtime pulse synchronized.',
        type: 'order',
        event_type: 'ORDER_PLACED',
        is_read: false,
        read_status: false,
        role: 'CUSTOMER'
    });

    const options = {
        hostname: supabaseUrl.replace('https://', ''),
        port: 443,
        path: `/rest/v1/${tableName}`,
        method: 'POST',
        headers: {
            'apikey': serviceKey,
            'Authorization': `Bearer ${serviceKey}`,
            'Content-Type': 'application/json'
        }
    };

    return new Promise((resolve) => {
        const req = https.request(options, (res) => {
            res.on('data', () => { });
            res.on('end', () => resolve(res.statusCode));
        });
        req.on('error', () => resolve(500));
        req.write(data);
        req.end();
    });
}

(async () => {
    for (const uid of targets) {
        const res = await send(uid);
        console.log(`Sent to ${uid}: ${res}`);
    }
})();
