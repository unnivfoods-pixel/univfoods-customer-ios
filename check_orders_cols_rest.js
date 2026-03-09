const https = require('https');
const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s';

async function checkCols(tableName) {
    const options = {
        hostname: supabaseUrl.replace('https://', ''),
        port: 443,
        path: `/rest/v1/${tableName}?limit=1`,
        method: 'GET',
        headers: {
            'apikey': serviceKey,
            'Authorization': `Bearer ${serviceKey}`
        }
    };

    return new Promise((resolve) => {
        const req = https.request(options, (res) => {
            let body = '';
            res.on('data', d => body += d);
            res.on('end', () => {
                try {
                    const data = JSON.parse(body);
                    if (data.length > 0) {
                        const allCols = Object.keys(data[0]);
                        console.log("payment_status exists:", allCols.includes('payment_status'));
                        console.log("order_status exists:", allCols.includes('order_status'));
                        console.log("status exists:", allCols.includes('status'));
                    } else {
                        console.log(`No data in ${tableName} to check columns.`);
                    }
                    resolve();
                } catch (e) {
                    console.log(`Error parsing ${tableName} response:`, body);
                    resolve();
                }
            });
        });
        req.end();
    });
}

(async () => {
    const table = process.argv[2] || 'notifications';
    await checkCols(table);
})();
