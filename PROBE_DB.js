import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
    'https://dxqcruvarqgnscenixzf.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwMjQ2NzksImV4cCI6MjA4MzYwMDY3OX0.2Z_DubJZM0p_aIC_1-H_LuZIrf8twPxqLbURw3rrHxY'
);

async function probe() {
    // Check orders customer_id type
    // Use a hacky way to check column type if exec_sql is missing
    const { data: cols, error: err } = await supabase.from('orders').select('customer_id').limit(1);
    if (err) console.error("Probe Error:", err);
    else console.log("Orders customer_id example:", cols[0]?.customer_id);

    // Check vendor status
    const { data: vendors, error: vErr } = await supabase.from('vendors').select('id, name, is_open, is_verified, latitude, longitude').limit(5);
    console.log("Vendors:", vendors);
}

probe();
