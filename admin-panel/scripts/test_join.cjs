const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
    'https://dxqcruvarqgnscenixzf.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwMjQ2NzksImV4cCI6MjA4MzYwMDY3OX0.2Z_DubJZM0p_aIC_1-H_LuZIrf8twPxqLbURw3rrHxY'
);

async function check() {
    console.log("Testing join query...");
    const { data, error } = await supabase
        .from('orders')
        .select(`
        *,
        vendors(name),
        customer_profiles(full_name)
    `)
        .limit(5);

    if (error) {
        console.error("Join Query Error:", JSON.stringify(error, null, 2));
    } else {
        console.log("Join Results:", JSON.stringify(data, null, 2));
    }
}

check();
