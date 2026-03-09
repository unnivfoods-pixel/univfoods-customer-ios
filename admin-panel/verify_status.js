import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s';

const supabase = createClient(supabaseUrl, serviceRoleKey);

async function verifyAndForceStatus() {
    console.log(">>> [VERIFY] Checking order 3b08e900...");

    const orderId = '3b08e900-78a6-489f-9cfe-ac1ef9bceaaa';

    // Check current state
    const { data: order } = await supabase.from('orders').select('id, status, order_status, customer_id').eq('id', orderId).single();
    console.log("Order status / order_status:", order?.status, '/', order?.order_status);
    console.log("Customer ID:", order?.customer_id);

    // Verify tracking view
    const { data: view } = await supabase.from('order_tracking_stabilized_v1').select('order_id, order_status, customer_id').eq('order_id', orderId).maybeSingle();
    console.log("Tracking view order_status:", view?.order_status, "customer_id:", view?.customer_id);

    // Force update order_status to match status
    if (order && order.status !== order.order_status) {
        console.log(`FORCE SYNCING: ${order.order_status} → ${order.status}`);
        const { error } = await supabase.from('orders').update({ order_status: order.status }).eq('id', orderId);
        if (error) console.error("Error:", error);
        else console.log("SYNCED!");
    } else {
        console.log("Status already in sync:", order?.status);
    }

    // Test the RPC
    console.log("\nTesting update_order_status_v3 RPC...");
    const { error: rpcError } = await supabase.rpc('update_order_status_v3', {
        p_order_id: orderId,
        p_new_status: 'ACCEPTED'
    });
    if (rpcError) console.error("RPC Error:", rpcError.message);
    else console.log("RPC OK - Status set to ACCEPTED");

    // Verify after RPC
    const { data: after } = await supabase.from('orders').select('status, order_status').eq('id', orderId).single();
    console.log("AFTER RPC - status:", after?.status, "order_status:", after?.order_status);

    // Also verify tracking view picks it up
    const { data: viewAfter } = await supabase.from('order_tracking_stabilized_v1').select('order_status').eq('order_id', orderId).maybeSingle();
    console.log("TRACKING VIEW AFTER:", viewAfter?.order_status);
}

verifyAndForceStatus();
