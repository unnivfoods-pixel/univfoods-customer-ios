const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwMjQ2NzksImV4cCI6MjA4MzYwMDY3OX0.2Z_DubJZM0p_aIC_1-H_LuZIrf8twPxqLbURw3rrHxY';
const supabase = createClient(supabaseUrl, supabaseKey);

async function check() {
    const tables = ['customer_profiles', 'orders'];
    for (const table of tables) {
        const { data, error } = await supabase.from(table).select('*').limit(1);
        if (error) {
            console.log(`Error reading ${table}:`, error.message);
        } else {
            console.log(`Columns for ${table}:`, Object.keys(data[0] || {}));
        }
    }
}
check();
