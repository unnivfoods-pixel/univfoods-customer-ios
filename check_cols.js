
const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwMjQ2NzksImV4cCI6MjA4MzYwMDY3OX0.2Z_DubJZM0p_aIC_1-H_LuZIrf8twPxqLbURw3rrHxY';

async function getColumnDetails() {
    try {
        const response = await fetch(`${supabaseUrl}/rest/v1/vendors?select=*&limit=1`, {
            method: 'GET',
            headers: {
                'apikey': supabaseKey,
                'Authorization': `Bearer ${supabaseKey}`,
                'Prefer': 'count=exact'
            }
        });

        // This doesn't give us structure, but we can try to guess from the first row.
        const data = await response.json();
        console.log("Column names in vendors table:", Object.keys(data[0] || {}).join(', '));
    } catch (e) {
        console.error(e);
    }
}

getColumnDetails();
