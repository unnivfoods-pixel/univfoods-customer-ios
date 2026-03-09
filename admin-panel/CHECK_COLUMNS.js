import { createClient } from '@supabase/supabase-js';
const supabase = createClient('https://dxqcruvarqgnscenixzf.supabase.co', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwMjQ2NzksImV4cCI6MjA4MzYwMDY3OX0.2Z_DubJZM0p_aIC_1-H_LuZIrf8twPxqLbURw3rrHxY');

async function check() {
    const { data } = await supabase.from('orders').select('*').limit(1);
    const keys = Object.keys(data[0]);
    ['customer_name', 'customer_phone', 'delivery_address', 'delivery_pincode', 'delivery_phone', 'delivery_house_number'].forEach(k => {
        console.log(`${k}: ${keys.includes(k)}`);
    });
}
check();
