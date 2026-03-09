const https = require('https');
const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co';
const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwMjQ2NzksImV4cCI6MjA4MzYwMDY3OX0.2Z_DubJZM0p_aIC_1-H_LuZIrf8twPxqLbURw3rrHxY';

// Mock a vendor ID
const vendorId = 'TEST_VENDOR_ID';

async function fetchOrders() {
    const options = {
        hostname: supabaseUrl.replace('https://', ''),
        port: 443,
        path: `/rest/v1/orders?vendor_id=eq.${vendorId}`,
        method: 'GET',
        headers: {
            'apikey': anonKey,
            'Authorization': `Bearer ${anonKey}`
        }
    };

    return new Promise((resolve) => {
        const req = https.request(options, (res) => {
            let body = '';
            res.on('data', d => body += d);
            res.on('end', () => resolve({ status: res.statusCode, body }));
        });
        req.on('error', d => resolve({ status: 500, body: d.message }));
        req.end();
    });
}

(async () => {
    const res = await fetchOrders();
    console.log(`Status: ${res.status}`);
    console.log(`Result: ${res.body}`);
})();
