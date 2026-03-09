
const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwMjQ2NzksImV4cCI6MjA4MzYwMDY3OX0.2Z_DubJZM0p_aIC_1-H_LuZIrf8twPxqLbURw3rrHxY';

async function checkNextMissingField() {
    console.log("Checking for next required field after shop_name...");
    try {
        const response = await fetch(`${supabaseUrl}/rest/v1/vendors`, {
            method: 'POST',
            headers: {
                'apikey': supabaseKey,
                'Authorization': `Bearer ${supabaseKey}`,
                'Content-Type': 'application/json',
                'Prefer': 'params=single-object'
            },
            body: JSON.stringify({
                shop_name: "Test Field"
            })
        });

        const data = await response.json();
        console.log("Next error response:", JSON.stringify(data, null, 2));
    } catch (error) {
        console.error("Error:", error);
    }
}

checkNextMissingField();
