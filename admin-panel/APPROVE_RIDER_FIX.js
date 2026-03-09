
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co'
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s'

const supabase = createClient(supabaseUrl, serviceKey)

async function approveRider() {
    const userId = '9a9dcf48-c6e2-43d6-b4fb-ae6970b43da5';
    console.log(`Approving rider with user_id: ${userId}`);

    const { data, error } = await supabase
        .from('delivery_riders')
        .update({ is_approved: true })
        .eq('user_id', userId);

    if (error) {
        console.error("Error approving rider:", error);
    } else {
        console.log("Rider approved successfully!");
    }
}

approveRider();
