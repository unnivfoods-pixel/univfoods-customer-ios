import { createClient } from '@supabase/supabase-js';

const url = 'https://dxqcruvarqgnscenixzf.supabase.co';
const key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwMjQ2NzksImV4cCI6MjA4MzYwMDY3OX0.2Z_DubJZM0p_aIC_1-H_LuZIrf8twPxqLbURw3rrHxY';

const supabase = createClient(url, key);

async function check() {
    const { data, error } = await supabase.from('vendors').select('*');
    if (error) {
        console.error('ERROR:', error);
    } else {
        console.log('COUNT:', data.length);
        console.log('DATA:', JSON.stringify(data[0], null, 2));
    }
}

check();
