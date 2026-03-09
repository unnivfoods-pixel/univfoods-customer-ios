import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co'
const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwMjQ2NzksImV4cCI6MjA4MzYwMDY3OX0.2Z_DubJZM0p_aIC_1-H_LuZIrf8twPxqLbURw3rrHxY'

const supabase = createClient(supabaseUrl, anonKey)

async function checkNotifCols() {
    const { data, error } = await supabase.from('notifications').select('*').limit(1);
    if (data && data.length > 0) {
        console.log(`Columns in notifications:`, Object.keys(data[0]));
    } else {
        console.log(`No data in notifications to check columns.`);
    }
}

checkNotifCols();
