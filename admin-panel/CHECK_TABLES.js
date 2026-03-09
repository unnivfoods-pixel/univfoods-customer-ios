
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co'
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s'

const supabase = createClient(supabaseUrl, serviceKey)

async function listTables() {
    // This is a hacky way since Supabase JS doesn't have listTables
    // but we can try to select from common tables
    const tables = ['orders', 'users', 'chats', 'messages', 'support_tickets', 'vendors'];
    for (const t of tables) {
        const { error } = await supabase.from(t).select('*').limit(1);
        if (!error) {
            console.log(`Table '${t}' exists.`);
        } else {
            console.log(`Table '${t}' error: ${error.message}`);
        }
    }
}

listTables();
