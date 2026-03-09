const https = require('https');

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s';

async function updateLatest() {
    const getOptions = {
        hostname: supabaseUrl.replace('https://', ''),
        port: 443,
        path: `/rest/v1/orders?select=id,status&order=created_at.desc&limit=1`,
        method: 'GET',
        headers: {
            'apikey': serviceKey,
            'Authorization': `Bearer ${serviceKey}`,
            'Content-Type': 'application/json'
        }
    };

    const reqGet = https.request(getOptions, (res) => {
        let body = '';
        res.on('data', d => body += d);
        res.on('end', async () => {
            const data = JSON.parse(body);
            if (data.length > 0) {
                const orderId = data[0].id;
                console.log('Latest Order ID:', orderId);
                console.log('Current Status:', data[0].status);

                // Update it
                const patchOptions = {
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

                const reqPatch = https.request(patchOptions, (res) => {
                    let patchBody = '';
                    res.on('data', d => patchBody += d);
                    res.on('end', () => {
                        console.log('PATCH Result:', patchBody);
                    });
                });

                reqPatch.on('error', (e) => console.error(e));
                reqPatch.write(JSON.stringify({ status: 'ACCEPTED' }));
                reqPatch.end();
            }
        });
    });
    reqGet.end();
}

updateLatest();
