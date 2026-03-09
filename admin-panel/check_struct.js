import { createClient } from '@supabase/supabase-js';
const supabase = createClient('https://dxqcruvarqgnscenixzf.supabase.co', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwMjQ2NzksImV4cCI6MjA4MzYwMDY3OX0.2Z_DubJZM0p_aIC_1-H_LuZIrf8twPxqLbURw3rrHxY');

async function checkTable(table) {
    const { data, error } = await supabase.from(table).select('*').limit(1);
    console.log(`--- ${table} Check ---`);
    if (error) console.error(error);
    else console.log("Columns:", Object.keys(data[0] || {}));
}

async function run() {
    await checkTable('customer_profiles');
    await checkTable('users');
}
run();
