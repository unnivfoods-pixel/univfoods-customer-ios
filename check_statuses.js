const https = require('https');
const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s';

async function checkStatuses() {
    const options = {
        hostname: supabaseUrl.replace('https://', ''),
        port: 443,
        path: '/rest/v1/orders?select=status',
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
                const data = JSON.parse(body);
                const statuses = [...new Set(data.map(o => o.status))];
                console.log("Existing Statuses:", statuses);
            } catch (e) {
                console.log("Error:", body);
            }
        });
    });
    req.end();
}

checkStatuses();
