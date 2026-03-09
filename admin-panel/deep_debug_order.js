import { createClient } from '@supabase/supabase-js';
const supabase = createClient('https://dxqcruvarqgnscenixzf.supabase.co', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwMjQ2NzksImV4cCI6MjA4MzYwMDY3OX0.2Z_DubJZM0p_aIC_1-H_LuZIrf8twPxqLbURw3rrHxY');

async function debugOrder() {
    const { data: order, error } = await supabase.from('orders').select('*').ilike('id', '145a4f4b%').single();
    if (error) {
        console.error("Order Fetch Error:", error);
        return;
    }

    const { data: profile } = await supabase.from('customer_profiles').select('*').eq('id', order.customer_id || order.user_id).maybeSingle();

    console.log("=== ORDER DATA ===");
    console.log("ID:", order.id);
    console.log("Delivery Phone:", order.delivery_phone);
    console.log("Delivery Pincode:", order.delivery_pincode);
    console.log("Delivery House:", order.delivery_house_number);
    console.log("Address:", order.delivery_address || order.address);
    console.log("Snapshot Name:", order.customer_name_snapshot);
    console.log("Snapshot Phone:", order.customer_phone_snapshot);

    console.log("\n=== LINKED PROFILE ===");
    if (profile) {
        console.log("Full Name:", profile.full_name);
        console.log("Phone:", profile.phone);
    } else {
        console.log("No profile found for ID:", order.customer_id || order.user_id);
    }
}
debugOrder();
