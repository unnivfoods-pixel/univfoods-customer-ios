const https = require('https');
const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s';

async function listRpcs() {
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
            const matches = body.match(/\/rpc\/[a-zA-Z0-9_]+/g);
            if (matches) {
                [...new Set(matches)].forEach(m => {
                    if (m.toLowerCase().includes('sql') || m.toLowerCase().includes('exec') || m.toLowerCase().includes('run')) {
                        console.log(`RPC: ${m}`);
                    }
                });
            }
        });
    });
    req.end();
}

listRpcs();
