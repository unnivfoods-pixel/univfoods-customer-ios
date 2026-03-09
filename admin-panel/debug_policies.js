
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co'
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s'

const supabase = createClient(supabaseUrl, serviceKey)

async function checkOldPolicies() {
    console.log("Checking current legal_documents data...");
    const { data, error } = await supabase.from('legal_documents').select('*');

    if (error) {
        console.error("Error fetching policies:", error.message);
        return;
    }

    if (!data || data.length === 0) {
        console.log("No policies found in legal_documents.");
        return;
    }

    console.log(`Found ${data.length} policies.`);
    data.forEach(p => {
        console.log(`- ID: ${p.id}, Title: ${p.title}, Audience: ${p.target_audience}, Status: ${p.status}, Category: ${p.category}`);
    });
}

checkOldPolicies();
