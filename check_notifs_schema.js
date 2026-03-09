const https = require('https');

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6ImpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s';

const options = {
    hostname: supabaseUrl.replace('https://', ''),
    port: 443,
    path: '/rest/v1/',
    method: 'GET',
    headers: {
        'apikey': serviceKey,
        'Authorization': `Bearer ${serviceKey}`
    }
};

const req = https.request(options, (res) => {
    let body = '';
    res.on('data', d => body += d);
    res.on('end', () => {
        try {
            const doc = JSON.parse(body);
            const props = doc.definitions.notifications.properties;
            for (const p in props) {
                console.log(`${p}: ${props[p].type} (${props[p].format || 'no format'})`);
            }
        } catch (e) {
            console.log("Error:", e.message);
        }
    });
});

req.on('error', (e) => {
    console.error(`Error: ${e.message}`);
});

req.end();
