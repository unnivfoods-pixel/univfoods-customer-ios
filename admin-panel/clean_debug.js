import { createClient } from '@supabase/supabase-js';
const supabase = createClient('https://dxqcruvarqgnscenixzf.supabase.co', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwMjQ2NzksImV4cCI6MjA4MzYwMDY3OX0.2Z_DubJZM0p_aIC_1-H_LuZIrf8twPxqLbURw3rrHxY');

async function debug() {
    const { data: o } = await supabase.from('orders').select('*').ilike('id', '145A4F4B%').single();
    if (!o) { console.log("Order not found"); return; }

    console.log("--- ORDER DUMP ---");
    console.log("ID:", o.id);
    console.log("Customer ID:", o.customer_id);
    console.log("User ID:", o.user_id);
    console.log("Delivery Phone:", o.delivery_phone);
    console.log("Delivery Pincode:", o.delivery_pincode);
    console.log("Delivery House:", o.delivery_house_number);
    console.log("Snap Name:", o.customer_name_snapshot);
    console.log("Snap Phone:", o.customer_phone_snapshot);
    console.log("Legacy Name:", o.customer_name_legacy);
    console.log("Legacy Phone:", o.customer_phone_legacy);
    console.log("--- PROFILE CHECK ---");

    const uid = o.customer_id || o.user_id;
    if (uid) {
        const { data: p } = await supabase.from('customer_profiles').select('*').eq('id', uid).single();
        if (p) {
            console.log("Profile Found:", JSON.stringify(p, null, 2));
        } else {
            console.log("No Profile Found for ID:", uid);
        }
    }
}
debug();
