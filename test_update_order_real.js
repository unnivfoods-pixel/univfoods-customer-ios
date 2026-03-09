const https = require('https');

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s';

const orderId = 'e6bc6ee6-f68a-4d1f-b103-e60da7f7f457';

const options = {
    hostname: supabaseUrl.replace('https://', ''),
    port: 443,
    path: `/rest/v1/orders?id=eq.${orderId}`,
    method: 'PATCH',
    headers: {
        'apikey': serviceKey,
        'Authorization': `Bearer ${serviceKey}`,
        'Content-Type': 'application/json',
        'Prefer': 'return=representation'
    }
};

const req = https.request(options, (res) => {
    let body = '';
    res.on('data', d => body += d);
    res.on('end', () => {
        console.log('Update result:', body);
    });
});

req.on('error', (e) => {
    console.error(`Error: ${e.message}`);
});

req.write(JSON.stringify({ status: 'ACCEPTED' }));
req.end();
