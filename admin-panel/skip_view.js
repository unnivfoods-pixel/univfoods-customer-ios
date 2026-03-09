import { createClient } from '@supabase/supabase-js';
const supabase = createClient('https://dxqcruvarqgnscenixzf.supabase.co', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s');

async function createView() {
    console.log("Creating View...");
    const sql = `
CREATE OR REPLACE VIEW order_details_v3 AS
SELECT 
    o.*,
    v.name as vendor_name,
    -- Aggressive Identity Resolution
    COALESCE(p.full_name, o.customer_name_snapshot, o.customer_name_legacy, 'Guest User') as display_customer_name,
    COALESCE(o.delivery_phone, o.customer_phone_snapshot, o.customer_phone_legacy, p.phone) as display_customer_phone,
    COALESCE(o.delivery_pincode, (regexp_matches(COALESCE(o.delivery_address, o.address), '\\b\\d{6}\\b'))[1]) as display_pincode
FROM orders o
LEFT JOIN vendors v ON o.vendor_id::text = v.id::text
LEFT JOIN customer_profiles p ON o.customer_id::text = p.id::text OR o.user_id::text = p.id::text;
    `;

    // Since exec_sql is missing, I can't run this easily unless I find another way or skip the view.
    // I'll skip the view and just make the JS mapping in Orders.jsx even BETTER.
}
createView();
