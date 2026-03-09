import { createClient } from '@supabase/supabase-js';
const supabase = createClient('https://dxqcruvarqgnscenixzf.supabase.co', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwMjQ2NzksImV4cCI6MjA4MzYwMDY3OX0.2Z_DubJZM0p_aIC_1-H_LuZIrf8twPxqLbURw3rrHxY');

async function checkTypes() {
    const { data, error } = await supabase.rpc('get_table_info', { p_table: 'customer_profiles' });
    if (error) {
        // Fallback: try to insert a string and see the error
        const { error: insErr } = await supabase.from('customer_profiles').insert({ id: 'test_string' });
        console.error("Insert Error:", insErr);
    } else {
        console.log("Table Info:", data);
    }
}
checkTypes();
