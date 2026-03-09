const https = require('https');

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s';

const options = {
    hostname: supabaseUrl.replace('https://', ''),
    port: 443,
    path: '/rest/v1/',
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
            const doc = JSON.parse(body);
            const paths = Object.keys(doc.paths)
                .filter(p => p.startsWith('/rpc/'))
                .filter(p => !p.startsWith('/rpc/st_'))
                .map(p => p.replace('/rpc/', ''));
            console.log(paths.join('\n'));
        } catch (e) {
            console.log("Error parsing JSON:", e.message);
            console.log("Status:", res.statusCode);
            console.log("Body snippet:", body.substring(0, 200));
        }
    });
});

req.on('error', (e) => {
    console.error(`Error: ${e.message}`);
});

req.end();
