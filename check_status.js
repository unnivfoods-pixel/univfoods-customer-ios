
const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwMjQ2NzksImV4cCI6MjA4MzYwMDY3OX0.2Z_DubJZM0p_aIC_1-H_LuZIrf8twPxqLbURw3rrHxY';

async function checkStatusValues() {
    try {
        const response = await fetch(`${supabaseUrl}/rest/v1/vendors?select=status,name&limit=10`, {
            method: 'GET',
            headers: {
                'apikey': supabaseKey,
                'Authorization': `Bearer ${supabaseKey}`
            }
        });

        const data = await response.json();
        console.log("Current vendor statuses in DB:");
        data.forEach(v => console.log(`- ${v.name}: ${v.status}`));
    } catch (e) {
        console.error(e);
    }
}

checkStatusValues();
