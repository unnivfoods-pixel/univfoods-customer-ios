import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co'
const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwMjQ2NzksImV4cCI6MjA4MzYwMDY3OX0.2Z_DubJZM0p_aIC_1-H_LuZIrf8twPxqLbURw3rrHxY'

const supabase = createClient(supabaseUrl, anonKey)

async function probe() {
    const tables = [
        'refunds',
        'refund_requests',
        'support_chats',
        'support_messages',
        'support_tickets',
        'ticket_messages',
        'chat_messages'
    ];

    for (const t of tables) {
        const { error } = await supabase.from(t).select('*').limit(0);
        if (error) {
            console.log(`[ABSENT] ${t}: ${error.message}`);
        } else {
            console.log(`[EXISTS] ${t}`);
        }
    }
}

probe();
