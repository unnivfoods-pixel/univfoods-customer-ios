const https = require('https');
const fs = require('fs');

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s';

async function runSql() {
    const filePath = process.argv[2] || './LOCATION_MUST_CONTROL_EVERYTHING.sql';
    const sql = fs.readFileSync(filePath, 'utf8');

    const data = JSON.stringify({
        sql: sql
    });

    const options = {
        hostname: supabaseUrl.replace('https://', ''),
        port: 443,
        path: '/rest/v1/rpc/exec_sql',
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Content-Length': data.length,
            'apikey': serviceKey,
            'Authorization': 'Bearer ' + serviceKey
        }
    };

    const req = https.request(options, (res) => {
        let responseBody = '';
        res.on('data', (chunk) => {
            responseBody += chunk;
        });
        res.on('end', () => {
            if (res.statusCode >= 200 && res.statusCode < 300) {
                console.log('SQL executed successfully!');
            } else {
                console.error('Error executing SQL:', res.statusCode, responseBody);
                process.exit(1);
            }
        });
    });

    req.on('error', (error) => {
        console.error('Request Error:', error);
        process.exit(1);
    });

    req.write(data);
    req.end();
}

runSql();
