import { createClient } from '@supabase/supabase-js';

const url = 'https://dxqcruvarqgnscenixzf.supabase.co';
const key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwMjQ2NzksImV4cCI6MjA4MzYwMDY3OX0.2Z_DubJZM0p_aIC_1-H_LuZIrf8twPxqLbURw3rrHxY';

const supabase = createClient(url, key);

async function check() {
    const { data, error } = await supabase.rpc('get_table_columns', {
        p_table_name: 'vendors'
    });
    if (error) {
        // Fallback: use a simple query
        const { data: v } = await supabase.from('vendors').select().limit(1);
        console.log('SAMPLE_ROW:', JSON.stringify(v ? v[0] : 'EMPTY', null, 2));
    } else {
        console.log('COLUMNS:', data);
    }
}

check();
