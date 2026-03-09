import { createClient } from '@supabase/supabase-js';
const supabase = createClient('https://dxqcruvarqgnscenixzf.supabase.co', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwMjQ2NzksImV4cCI6MjA4MzYwMDY3OX0.2Z_DubJZM0p_aIC_1-H_LuZIrf8twPxqLbURw3rrHxY');

async function test() {
    const { data, error } = await supabase.rpc('exec_sql', { sql: 'SELECT 1' });
    console.log('exec_sql:', error ? error.message : 'EXISTS');

    if (error) {
        const { error: error2 } = await supabase.rpc('execute_sql', { sql: 'SELECT 1' });
        console.log('execute_sql:', error2 ? error2.message : 'EXISTS');
    }
}
test();
