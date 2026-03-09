import { createClient } from '@supabase/supabase-js';
const supabase = createClient('https://dxqcruvarqgnscenixzf.supabase.co', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwMjQ2NzksImV4cCI6MjA4MzYwMDY3OX0.2Z_DubJZM0p_aIC_1-H_LuZIrf8twPxqLbURw3rrHxY');

async function debug() {
    const { data } = await supabase.from('orders').select('id, address, delivery_address, delivery_phone, delivery_pincode, delivery_house_number, customer_id, user_id, customer_name_snapshot, customer_phone_snapshot, customer_name_legacy, customer_phone_legacy').ilike('id', '145A4F4B%').single();
    if (data) {
        console.log("ORDER 145A4F4B DATA:");
        console.log(JSON.stringify(data, null, 2));
    } else {
        console.log("Order not found");
    }
}
debug();
