
const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwMjQ2NzksImV4cCI6MjA4MzYwMDY3OX0.2Z_DubJZM0p_aIC_1-H_LuZIrf8twPxqLbURw3rrHxY';

async function checkVendorsTable() {
    console.log("Checking vendors table structure...");
    try {
        // We can use a query that fails or returns nothing but gives context, 
        // or just try to insert a minimal row and see what it asks for.
        // But better is to check the PostgreSQL catalog if we have an RPC for it.
        // Since we don't know if 'exec_sql' exists, let's try a dry run insert.

        const response = await fetch(`${supabaseUrl}/rest/v1/vendors`, {
            method: 'POST',
            headers: {
                'apikey': supabaseKey,
                'Authorization': `Bearer ${supabaseKey}`,
                'Content-Type': 'application/json',
                'Prefer': 'params=single-object' // Try to get error for missing fields
            },
            body: JSON.stringify({})
        });

        const data = await response.json();
        console.log("Error response for empty insert:", JSON.stringify(data, null, 2));
    } catch (error) {
        console.error("Error:", error);
    }
}

checkVendorsTable();
