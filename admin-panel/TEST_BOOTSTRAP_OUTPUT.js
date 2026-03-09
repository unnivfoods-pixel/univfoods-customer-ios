import { createClient } from '@supabase/supabase-js';

const url = 'https://dxqcruvarqgnscenixzf.supabase.co';
const key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwMjQ2NzksImV4cCI6MjA4MzYwMDY3OX0.2Z_DubJZM0p_aIC_1-H_LuZIrf8twPxqLbURw3rrHxY';

const supabase = createClient(url, key);

async function check() {
    const { data, error } = await supabase.rpc('get_unified_bootstrap_data', {
        p_user_id: 'guest_1234',
        p_role: 'customer'
    });
    if (error) {
        console.error('ERROR:', error);
    } else {
        console.log('BOOTSTRAP DATA KEYS:', Object.keys(data));
        if (data.active_orders && data.active_orders.length > 0) {
            console.log('ORDER SAMPLE:', JSON.stringify(data.active_orders[0], null, 2));
        } else {
            console.log('NO ACTIVE ORDERS FOUND');
        }
    }
}

check();
