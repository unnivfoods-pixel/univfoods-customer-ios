const https = require('https');

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s';

const tableName = 'customer_profiles';
const phone = '8897868951';

const options = {
    hostname: supabaseUrl.replace('https://', ''),
    port: 443,
    path: `/rest/v1/${tableName}?phone=eq.${phone}&select=id,full_name,phone`,
    method: 'GET',
    headers: {
        'apikey': serviceKey,
        'Authorization': `Bearer ${serviceKey}`,
        'Content-Type': 'application/json'
    }
};

const req = https.request(options, (res) => {
    let body = '';
    res.on('data', d => body += d);
    res.on('end', () => {
        console.log(body);
    });
});

req.on('error', (e) => {
    console.error(`Error: ${e.message}`);
});

req.end();
