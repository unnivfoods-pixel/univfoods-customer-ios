const https = require('https');
const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s';

async function getCols(tableName) {
    const url = `${supabaseUrl}/rest/v1/rpc/exec_sql`;
    // Maybe try different param name: sql_query, query, sql
    const paramVariations = ['sql', 'sql_query', 'query', 'p_query'];

    for (const pName of paramVariations) {
        console.log(`Trying param: ${pName}`);
        const data = JSON.stringify({ [pName]: `SELECT column_name FROM information_schema.columns WHERE table_name = '${tableName}';` });
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

        const resBody = await new Promise((resolve) => {
            const req = https.request(options, (res) => {
                let body = '';
                res.on('data', d => body += d);
                res.on('end', () => resolve({ status: res.statusCode, body }));
            });
            req.on('error', e => resolve({ status: 500, body: e.message }));
            req.write(data);
            req.end();
        });

        console.log(`Status: ${resBody.status}, Body: ${resBody.body}`);
        if (resBody.status === 200) {
            console.log("SUCCESS!");
            return;
        }
    }
}

getCols('orders');
