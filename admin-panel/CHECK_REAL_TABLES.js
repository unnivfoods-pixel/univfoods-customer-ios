import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co'
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwMjQ2NzksImV4cCI6MjA4MzYwMDY3OX0.2Z_DubJZM0p_aIC_1-H_LuZIrf8twPxqLbURw3rrHxY'

const supabase = createClient(supabaseUrl, supabaseKey)

async function checkTables() {
    const tables = ['payments', 'payment_rules', 'platform_settings', 'audit_logs', 'orders', 'users', 'vendors', 'profiles'];
    for (const table of tables) {
        const { error } = await supabase.from(table).select('*').limit(1);
        if (error) {
            console.log(`Table ${table}: NOT FOUND or Error (${error.message})`);
        } else {
            console.log(`Table ${table}: OK`);
        }
    }
}

checkTables();
