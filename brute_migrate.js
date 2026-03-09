const https = require('https');
const fs = require('fs');
const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s';

const sqlPath = 'c:\\Users\\ganap\\.gemini\\antigravity\\scratch\\curry-delivery-platform\\ULTIMATE_NOTIFICATION_FIX_V71.sql';
const sql = fs.readFileSync(sqlPath, 'utf8');

async function tryRpc(rpcName, pName) {
    console.log(`Trying ${rpcName} with param ${pName}...`);
    const data = JSON.stringify({ [pName]: sql });
    const options = {
        hostname: supabaseUrl.replace('https://', ''),
        port: 443,
        path: `/rest/v1/rpc/${rpcName}`,
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
        req.on('error', e => resolve({ status: 500, body: e.message }));
        req.write(data);
        req.end();
    });
}

(async () => {
    // These names were seen or common
    const names = ['exec_sql', 'run_sql', 'execute_sql'];
    const params = ['sql', 'query', 'p_query', 'sql_query'];

    for (const name of names) {
        for (const p of params) {
            const res = await tryRpc(name, p);
            if (res.status === 200 || res.status === 204) {
                console.log(`SUCCESS with ${name}(${p})!`);
                process.exit(0);
            }
            console.log(`Failed: ${res.status} - ${res.body.substring(0, 50)}`);
        }
    }
    console.log("Could not find a workable RPC. Please apply the SQL manually.");
})();
