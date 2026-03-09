
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
        'Authorization': `Bearer ${serviceKey}`
    }
};

const req = https.request(options, (res) => {
    let body = '';
    res.on('data', d => body += d);
    res.on('end', () => {
        try {
            const spec = JSON.parse(body);
            const rpcs = Object.keys(spec.paths).filter(p => p.startsWith('/rpc/'));
            console.log("Total RPCs found:", rpcs.length);
            console.log(JSON.stringify(rpcs.sort(), null, 2));
        } catch (e) {
            console.error("PARSE ERROR:", e.message);
            console.log("BODY:", body);
        }
    });
});
req.on('error', e => console.error(e));
req.end();
