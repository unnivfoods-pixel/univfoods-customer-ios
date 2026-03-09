import { createClient } from '@supabase/supabase-js';
const supabase = createClient('https://dxqcruvarqgnscenixzf.supabase.co', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwMjQ2NzksImV4cCI6MjA4MzYwMDY3OX0.2Z_DubJZM0p_aIC_1-H_LuZIrf8twPxqLbURw3rrHxY');

async function testJoin() {
    console.log("Testing Join...");
    const { data, error } = await supabase
        .from('orders')
        .select(`
            id,
            vendors:vendor_id (name)
        `)
        .limit(1);

    if (error) {
        console.error('JOIN ERROR:', error);
    } else {
        console.log('JOIN SUCCESS:', data);
    }
}
testJoin();
