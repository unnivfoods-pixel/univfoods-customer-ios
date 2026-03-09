const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co';
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY; // I'll assume it's available or use the anon one if permitted for this query

const supabase = createClient(supabaseUrl, supabaseKey);

async function checkPublication() {
    const { data, error } = await supabase.rpc('check_pub_status', {});
    // If rpc doesn't exist, try raw query? But I can't do raw queries easily.
    // I'll try to just select from notifications and see if it works as a proxy? No.

    // I'll try to get the publication info using a custom RPC if I can create one, 
    // or I'll just check if the notifications are even being inserted.

    const { data: notifs, error: fetchError } = await supabase
        .from('notifications')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(5);

    if (fetchError) {
        console.error('Error fetching notifications:', fetchError);
    } else {
        console.log('Recent Notifications:', JSON.stringify(notifs, null, 2));
    }
}

checkPublication();
