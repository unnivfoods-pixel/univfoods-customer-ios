const { createClient } = require('@supabase/supabase-js');
const SUPABASE_URL = 'https://dxqcruvarqgnscenixzf.supabase.co';
const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwMjQ2NzksImV4cCI6MjA4MzYwMDY3OX0.2Z_DubJZM0p_aIC_1-H_LuZIrf8twPxqLbURw3rrHxY';
const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

async function check() {
    const { data: users, error } = await supabase.from('users').select('*');
    console.log('--- PUBLIC.USERS ---');
    console.log(JSON.stringify(users, null, 2));

    const { data: vendors, error: vError } = await supabase.from('vendors').select('*');
    console.log('\n--- PUBLIC.VENDORS ---');
    console.log(JSON.stringify(vendors, null, 2));
}
check();
