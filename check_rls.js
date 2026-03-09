
const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwMjQ2NzksImV4cCI6MjA4MzYwMDY3OX0.2Z_DubJZM0p_aIC_1-H_LuZIrf8twPxqLbURw3rrHxY';

async function checkRLS() {
    console.log("Checking RLS and Triggers (Simulated check)...");
    try {
        // Since we don't have direct SQL access easily without knowing the RPC, 
        // let's try to see if a simple select works (testing current user permissions).
        const response = await fetch(`${supabaseUrl}/rest/v1/vendors?select=id&limit=1`, {
            method: 'GET',
            headers: {
                'apikey': supabaseKey,
                'Authorization': `Bearer ${supabaseKey}`
            }
        });
        console.log("SELECT status:", response.status);
        const data = await response.json();
        console.log("SELECT data length:", data.length);

        // Now let's try an insert with a specific ID to see if it triggers an error that reveals something
        const testId = '00000000-0000-0000-0000-000000000000';
        const insertRes = await fetch(`${supabaseUrl}/rest/v1/vendors`, {
            method: 'POST',
            headers: {
                'apikey': supabaseKey,
                'Authorization': `Bearer ${supabaseKey}`,
                'Content-Type': 'application/json',
                'Prefer': 'return=representation'
            },
            body: JSON.stringify({
                id: testId,
                name: "RLS Test",
                shop_name: "RLS Test",
                cuisine_type: "Test",
                status: "ONLINE",
                address: "Test"
            })
        });
        const insertData = await insertRes.json();
        console.log("Insert status:", insertRes.status);
        console.log("Insert response:", JSON.stringify(insertData, null, 2));

        // If it succeeded, delete it
        if (insertRes.status === 201) {
            await fetch(`${supabaseUrl}/rest/v1/vendors?id=eq.${testId}`, {
                method: 'DELETE',
                headers: {
                    'apikey': supabaseKey,
                    'Authorization': `Bearer ${supabaseKey}`
                }
            });
            console.log("Cleanup: Deleted test row.");
        }
    } catch (e) {
        console.error(e);
    }
}

checkRLS();
