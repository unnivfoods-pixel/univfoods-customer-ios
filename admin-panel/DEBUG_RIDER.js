
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co'
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s'

const supabase = createClient(supabaseUrl, serviceKey)

async function debugRider() {
    const email = 'ganaparthinarasimha@gmail.com';
    console.log(`Debugging rider with email: ${email}`);

    // Find the user first
    const { data: userData, error: userError } = await supabase.from('delivery_riders').select('*').eq('user_id', '9a9dcf48-c6e2-43d6-b4fb-ae6970b43da5');

    if (userError) {
        console.error("Error fetching rider:", userError);
    } else {
        console.log("Rider Data:", userData);
    }
}

debugRider();
