import { createClient } from '@supabase/supabase-js';
const supabase = createClient('https://dxqcruvarqgnscenixzf.supabase.co', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwMjQ2NzksImV4cCI6MjA4MzYwMDY3OX0.2Z_DubJZM0p_aIC_1-H_LuZIrf8twPxqLbURw3rrHxY');

async function debugOrders() {
    console.log("Fetching sample orders...");
    const { data, error } = await supabase
        .from('orders')
        .select('id, customer_id, customer_name, customer_phone, delivery_address, delivery_phone, delivery_pincode')
        .order('created_at', { ascending: false })
        .limit(5);

    if (error) {
        console.error('DEBUG ERROR:', error);
    } else {
        console.log('SAMPLE ORDERS:', JSON.stringify(data, null, 2));
    }
}
debugOrders();
