import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co'
const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwMjQ2NzksImV4cCI6MjA4MzYwMDY3OX0.2Z_DubJZM0p_aIC_1-H_LuZIrf8twPxqLbURw3rrHxY'

const supabase = createClient(supabaseUrl, anonKey)

async function checkCols() {
    for (const t of ['refunds', 'refund_requests']) {
        const { data, error } = await supabase.from(t).select('*').limit(1);
        if (data && data.length > 0) {
            console.log(`Columns in ${t}:`, Object.keys(data[0]));
        } else {
            console.log(`No data in ${t} to check columns.`);
        }
    }
}

checkCols();
