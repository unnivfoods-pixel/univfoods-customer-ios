import { createClient } from '@supabase/supabase-js';
const supabase = createClient('https://dxqcruvarqgnscenixzf.supabase.co', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwMjQ2NzksImV4cCI6MjA4MzYwMDY3OX0.2Z_DubJZM0p_aIC_1-H_LuZIrf8twPxqLbURw3rrHxY');

async function checkProfile() {
    const uid = 'rrgtG3C1UHgIcBMMtfdSnF2Vxup2';
    const { data, error } = await supabase.from('customer_profiles').select('*').eq('id', uid).maybeSingle();
    console.log("Profile for", uid);
    console.log(JSON.stringify(data, null, 2));
}
checkProfile();
