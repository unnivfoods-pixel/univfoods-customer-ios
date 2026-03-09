
const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwMjQ2NzksImV4cCI6MjA4MzYwMDY3OX0.2Z_DubJZM0p_aIC_1-H_LuZIrf8twPxqLbURw3rrHxY';

async function testInsert() {
    console.log("Attempting to insert vendor via REST API (with shop_name)...");
    try {
        const response = await fetch(`${supabaseUrl}/rest/v1/vendors`, {
            method: 'POST',
            headers: {
                'apikey': supabaseKey,
                'Authorization': `Bearer ${supabaseKey}`,
                'Content-Type': 'application/json',
                'Prefer': 'return=representation'
            },
            body: JSON.stringify({
                name: "Test REST Vendor 2",
                shop_name: "Test REST Vendor 2", // Added this
                cuisine_type: "Indian",
                status: "ONLINE",
                address: "Test Address",
                phone: "1234567890",
                open_time: "09:00",
                close_time: "22:00",
                latitude: 12.9716,
                longitude: 77.5946
            })
        });

        const data = await response.json();
        console.log("Response status:", response.status);
        console.log("Response data:", JSON.stringify(data, null, 2));
    } catch (error) {
        console.error("Error:", error);
    }
}

testInsert();
