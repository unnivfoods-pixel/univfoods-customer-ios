import { createClient } from '@supabase/supabase-js';
import fs from 'fs';

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co';
const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwMjQ2NzksImV4cCI6MjA4MzYwMDY3OX0.2Z_DubJZM0p_aIC_1-H_LuZIrf8twPxqLbURw3rrHxY';

const supabase = createClient(supabaseUrl, anonKey);

async function check() {
    const { data, error } = await supabase.from('notifications').select('*').limit(5);
    if (error) {
        console.log("Error:", error.message);
    } else {
        fs.writeFileSync('notifs_dump.json', JSON.stringify(data, null, 2));
        console.log("Dumped 5 notifications to notifs_dump.json");
    }
}
check();
