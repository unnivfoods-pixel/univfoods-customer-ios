import { createClient } from '@supabase/supabase-js';
const supabase = createClient('https://dxqcruvarqgnscenixzf.supabase.co', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwMjQ2NzksImV4cCI6MjA4MzYwMDY3OX0.2Z_DubJZM0p_aIC_1-H_LuZIrf8twPxqLbURw3rrHxY');

async function checkProfiles() {
    const { data: profiles, error } = await supabase.from('customer_profiles').select('*').limit(5);
    if (error) {
        console.error("Error fetching profiles:", error);
    } else {
        console.log("SAMPLE PROFILES:");
        console.log(JSON.stringify(profiles, null, 2));
    }

    const { data: users, error: uErr } = await supabase.from('users').select('*').limit(5);
    if (uErr) {
        console.error("Error fetching users:", uErr);
    } else {
        console.log("SAMPLE USERS:");
        console.log(JSON.stringify(users, null, 2));
    }
}
checkProfiles();
