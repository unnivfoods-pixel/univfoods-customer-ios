const https = require('https');

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s';

const options = {
    hostname: supabaseUrl.replace('https://', ''),
    port: 443,
    path: `/rest/v1/customer_profiles?select=phone,id`,
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
        try {
            const data = JSON.parse(body);
            if (!Array.isArray(data)) {
                console.log('Not an array:', data);
                return;
            }
            const myPhone = '8897868951';
            const myProfiles = data.filter(p => p.phone && p.phone.trim() === myPhone);
            console.log('Profiles for 8897868951:', JSON.stringify(myProfiles, null, 2));
        } catch (e) {
            console.error('Json Error:', e.message);
            console.log('Body:', body);
        }
    });
});

req.on('error', (e) => {
    console.error(`Error: ${e.message}`);
});

req.end();
