import { createClient } from '@supabase/supabase-js';

const url = 'https://dxqcruvarqgnscenixzf.supabase.co';
const key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwMjQ2NzksImV4cCI6MjA4MzYwMDY3OX0.2Z_DubJZM0p_aIC_1-H_LuZIrf8twPxqLbURw3rrHxY';

const supabase = createClient(url, key);

async function check() {
    const { data, error } = await supabase.rpc('get_nearby_vendors_v6', {
        p_customer_lat: 9.5126,
        p_customer_lng: 77.6335
    });
    console.log('GET_VENDORS_V6:', { data, error });

    const { data: d2, error: e2 } = await supabase.rpc('place_order_v8', {
        p_customer_id: 'test',
        p_vendor_id: 'test',
        p_items: [],
        p_total: 0,
        p_address: 'test',
        p_lat: 0,
        p_lng: 0,
        p_payment_method: 'test',
        p_instructions: 'test',
        p_address_id: null
    });
    console.log('PLACE_ORDER_V8:', { data: d2, error: e2 });
}

check();
