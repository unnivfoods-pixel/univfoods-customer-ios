const https = require('https');

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s';

const queries = [
    `SELECT p.pubname, t.schemaname, t.tablename FROM pg_publication p JOIN pg_publication_tables t ON p.pubname = t.pubname WHERE p.pubname = 'supabase_realtime';`,
    `SELECT pubname, puballtables FROM pg_publication WHERE pubname = 'supabase_realtime';`
];

async function runSql(sql) {
    const data = JSON.stringify({ sql_query: sql });
    const options = {
        hostname: supabaseUrl.replace('https://', ''),
        port: 443,
        path: `/rest/v1/rpc/exec_sql`,
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'apikey': serviceKey,
            'Authorization': `Bearer ${serviceKey}`
        }
    };

    return new Promise((resolve) => {
        const req = https.request(options, (res) => {
            let body = '';
            res.on('data', d => body += d);
            res.on('end', () => resolve({ status: res.statusCode, body }));
        });
        req.on('error', d => resolve({ status: 500, body: d.message }));
        req.write(data);
        req.end();
    });
}

(async () => {
    for (const sql of queries) {
        console.log(`\n--- QUERY ---\n${sql}`);
        const res = await runSql(sql);
        console.log(`Status: ${res.status}`);
        console.log(`Result: ${res.body}`);
    }
})();
