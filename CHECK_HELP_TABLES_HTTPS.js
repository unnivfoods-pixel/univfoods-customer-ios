const https = require('https');

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6ImpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s';

async function checkTable(table) {
    return new Promise((resolve) => {
        const options = {
            hostname: supabaseUrl.replace('https://', ''),
            port: 443,
            path: `/rest/v1/${table}?limit=1`,
            method: 'GET',
            headers: {
                'apikey': serviceKey,
                'Authorization': 'Bearer ' + serviceKey
            }
        };

        const req = https.request(options, (res) => {
            let body = '';
            res.on('data', (chunk) => body += chunk);
            res.on('end', () => {
                if (res.statusCode >= 200 && res.statusCode < 300) {
                    resolve(`✅ ${table}: Exists`);
                } else {
                    resolve(`❌ ${table}: ${res.statusCode} ${body}`);
                }
            });
        });

        req.on('error', (e) => resolve(`❌ ${table}: ${e.message}`));
        req.end();
    });
}

async function run() {
    const tables = [
        'faqs',
        'support_tickets',
        'partner_applications',
        'safety_reports',
        'legal_documents',
        'system_settings',
        'refund_requests'
    ];

    for (const table of tables) {
        process.stdout.write(await checkTable(table) + '\n');
    }
}

run();
