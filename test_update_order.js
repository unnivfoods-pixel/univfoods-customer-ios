const https = require('https');

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s';

const options = {
    hostname: supabaseUrl.replace('https://', ''),
    port: 443,
    path: `/rest/v1/rpc/get_triggers`, // I'll assume I can't do this easily.
    method: 'GET',
    headers: {
        'apikey': serviceKey,
        'Authorization': `Bearer ${serviceKey}`,
        'Content-Type': 'application/json'
    }
};

// I'll try to find a way to get trigger info.
// Actually, I'll just check if the update fails when I try it manually.

const req = https.request({
    ...options,
    path: `/rest/v1/orders?id=eq.e6bc6ee6-f68a-4d1f-b10...`, // use a real id
    method: 'PATCH',
    headers: {
        ...options.headers,
        'Prefer': 'return=representation'
    }
}, (res) => {
    let body = '';
    res.on('data', d => body += d);
    res.on('end', () => {
        console.log('Update result:', body);
    });
});

req.write(JSON.stringify({ status: 'ACCEPTED' }));
req.end();
