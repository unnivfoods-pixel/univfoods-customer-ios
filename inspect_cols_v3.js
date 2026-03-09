
const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwMjQ2NzksImV4cCI6MjA4MzYwMDY3OX0.2Z_DubJZM0p_aIC_1-H_LuZIrf8twPxqLbURw3rrHxY';

async function fullSchemaInspect() {
    try {
        console.log("Inspecting columns of the vendors table...");
        const response = await fetch(`${supabaseUrl}/rest/v1/vendors?select=*&limit=1`, {
            method: 'GET',
            headers: {
                'apikey': supabaseKey,
                'Authorization': `Bearer ${supabaseKey}`
            }
        });

        const data = await response.json();
        if (data && data.length > 0) {
            console.log("Full columns detected:");
            Object.keys(data[0]).forEach(k => console.log(`- ${k}`));
        } else {
            console.log("No data found to inspect columns.");
        }
    } catch (e) {
        console.error(e);
    }
}

fullSchemaInspect();
