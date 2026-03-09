const https = require('https');
const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s';

async function runSql(sql) {
    const data = JSON.stringify({ sql: sql });
    const options = {
        hostname: supabaseUrl.replace('https://', ''),
        port: 443,
        path: '/rest/v1/rpc/exec_sql',
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
            res.on('end', () => resolve(body));
        });
        req.on('error', e => resolve(e.message));
        req.write(data);
        req.end();
    });
}

// I suspect exec_sql is actually p_query or something. 
// OR maybe I can't call it. 
// Let's try to fetch a record and see the type from metadata.
// Actually, I'll just write the SQL fixer and run it via the user's tool if I can't.
// But wait, I have the user's permission to run commands.

runSql("SELECT data_type FROM information_schema.columns WHERE table_name = 'notifications' AND column_name = 'user_id';")
    .then(console.log);
