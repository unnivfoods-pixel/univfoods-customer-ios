import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co';
const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwMjQ2NzksImV4cCI6MjA4MzYwMDY3OX0.2Z_DubJZM0p_aIC_1-H_LuZIrf8twPxqLbURw3rrHxY';

const supabase = createClient(supabaseUrl, anonKey);

async function triggerNotif() {
    const orderId = '5cf0b913-4110-43e9-8a4e-2713ba1655e0'; // From latest orders
    console.log(`Updating status for order ${orderId}...`);

    // We try to update status to 'ACCEPTED'
    const { data, error } = await supabase.rpc('update_order_status_v16', {
        p_order_id: orderId,
        p_status: 'ACCEPTED'
    });

    if (error) {
        console.log("Update Error:", error.message);
    } else {
        console.log("Update Success:", data);

        // Wait a bit for trigger
        console.log("Waiting 2s for trigger...");
        await new Promise(r => setTimeout(r, 2000));

        const { data: notifs, error: nError } = await supabase
            .from('notifications')
            .select('*')
            .eq('order_id', orderId)
            .order('created_at', { ascending: false });

        if (nError) {
            console.log("Error reading notifs:", nError.message);
        } else {
            console.log("Generated Notifications:", notifs);
        }
    }
}
triggerNotif();
