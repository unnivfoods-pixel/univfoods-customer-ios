const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
    'https://dxqcruvarqgnscenixzf.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwMjQ2NzksImV4cCI6MjA4MzYwMDY3OX0.2Z_DubJZM0p_aIC_1-H_LuZIrf8twPxqLbURw3rrHxY'
);

async function check() {
    console.log("Checking orders...");
    const { data, error, count } = await supabase
        .from('orders')
        .select('*', { count: 'exact' });

    if (error) {
        console.error("Error fetching orders:", error);
    } else {
        console.log(`Found ${count} orders.`);
        if (data && data.length > 0) {
            console.log("Sample order:", JSON.stringify(data[0], null, 2));
        }
    }

    console.log("\nChecking customer_profiles...");
    const { count: cCount, error: cError } = await supabase
        .from('customer_profiles')
        .select('*', { count: 'exact', head: true });

    if (cError) {
        console.error("Error fetching customers:", cError);
    } else {
        console.log(`Found ${cCount} customers.`);
    }
}

check();
