const https = require('https');

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s';

const options = {
    hostname: supabaseUrl.replace('https://', ''),
    port: 443,
    path: `/rest/v1/customer_profiles?phone=is.not.null&select=phone,id`,
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
            const counts = {};
            data.forEach(p => {
                const phone = p.phone.trim();
                counts[phone] = (counts[phone] || 0) + 1;
            });
            const dupes = Object.entries(counts).filter(([p, c]) => c > 1);
            console.log('Duplicates:', JSON.stringify(dupes, null, 2));

            const myPhone = '8897868951';
            const myProfiles = data.filter(p => p.phone.trim() === myPhone);
            console.log('Profiles for 8897868951:', JSON.stringify(myProfiles, null, 2));
        } catch (e) {
            console.error('JSON Error:', e.message);
            console.log('Body:', body);
        }
    });
});

req.on('error', (e) => {
    console.error(`Error: ${e.message}`);
});

req.end();
