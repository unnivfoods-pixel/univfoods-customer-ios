const https = require('https');

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s';

const options = {
    hostname: supabaseUrl.replace('https://', ''),
    port: 443,
    path: `/rest/v1/notifications?limit=0`,
    method: 'GET',
    headers: {
        'apikey': serviceKey,
        'Authorization': `Bearer ${serviceKey}`,
        'Content-Type': 'application/json',
        'Prefer': 'count=exact'
    }
};

const req = https.request(options, (res) => {
    console.log('Status:', res.statusCode);
    console.log('Headers:', JSON.stringify(res.headers, null, 2));
    res.on('data', d => { });
});

req.on('error', (e) => {
    console.error(`Error: ${e.message}`);
});

req.end();
