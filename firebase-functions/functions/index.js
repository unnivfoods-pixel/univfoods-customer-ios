const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

/**
 * Triggered via Webhook from Supabase Database Changes
 * Expects a body containing { event: 'INSERT|UPDATE', record: { ...newData }, old_record: { ...oldData } }
 */
exports.onOrderStatusChange = functions.https.onRequest(async (req, res) => {
    // 1. Security check (Optional: Check a secret header from Supabase)
    // if (req.headers['x-supabase-key'] !== process.env.SUPABASE_WEBHOOK_KEY) return res.status(401).send('Unauthorized');

    const { event, record, old_record } = req.body;

    if (!record || !record.status) {
        return res.status(400).send('No status found');
    }

    const newStatus = record.status.toLowerCase();
    const oldStatus = old_record ? old_record.status.toLowerCase() : null;

    if (newStatus === oldStatus) {
        return res.status(200).send('No status change');
    }

    try {
        const notifications = [];

        // CUSTOMER NOTIFICATIONS
        if (newStatus === 'placed') {
            notifications.push(createNotification(record.customer_id, 'CUSTOMER', 'Order Placed', 'Your order has been received and is waiting for restaurant acceptance.'));
        } else if (newStatus === 'accepted') {
            notifications.push(createNotification(record.customer_id, 'CUSTOMER', 'Order Accepted', 'The restaurant has accepted your delicious order.'));
        } else if (newStatus === 'preparing') {
            notifications.push(createNotification(record.customer_id, 'CUSTOMER', 'Preparing Your Meal', 'The chef is now working their magic in the kitchen!'));
        } else if (newStatus === 'ready') {
            notifications.push(createNotification(record.customer_id, 'CUSTOMER', 'Food Ready!', 'Your meal is prepared and waiting for the delivery partner.'));
        } else if (newStatus === 'picked_up') {
            notifications.push(createNotification(record.customer_id, 'CUSTOMER', 'Order Picked Up', 'Our delivery partner is on the way with your food.'));
        } else if (newStatus === 'on_the_way') {
            notifications.push(createNotification(record.customer_id, 'CUSTOMER', 'Your food is nearby', 'Arriving in 5 minutes. Get ready to enjoy!'));
        } else if (newStatus === 'delivered') {
            notifications.push(createNotification(record.customer_id, 'CUSTOMER', 'Order Delivered', 'Hope you enjoy your meal! Rate your experience.'));
        } else if (newStatus === 'cancelled') {
            notifications.push(createNotification(record.customer_id, 'CUSTOMER', 'Order Cancelled', 'Your order was cancelled. Refund will be processed.'));
        }

        // VENDOR NOTIFICATIONS
        if (event === 'INSERT' || (event === 'UPDATE' && newStatus === 'placed')) {
            // Note: New orders usually sent via Realtime, but FCM is good for offline
            notifications.push(createNotification(record.vendor_id, 'VENDOR', 'New Order Received', `Order #${record.id.substring(0, 8)} is waiting for you.`));
        } else if (newStatus === 'cancelled') {
            notifications.push(createNotification(record.vendor_id, 'VENDOR', 'Order Cancelled', `Order #${record.id.substring(0, 8)} was cancelled by user.`));
        }

        // DELIVERY PARTNER NOTIFICATIONS
        if (record.delivery_partner_id && (newStatus === 'ready' || (event === 'UPDATE' && record.delivery_partner_id !== old_record.delivery_partner_id))) {
            notifications.push(createNotification(record.delivery_partner_id, 'DELIVERY', 'New Delivery Assigned', 'You have a new delivery request nearby!'));
        } else if (newStatus === 'cancelled' && record.delivery_partner_id) {
            notifications.push(createNotification(record.delivery_partner_id, 'DELIVERY', 'Order Cancelled', 'The order you were assigned was cancelled.'));
        }

        // Process all notifications
        await Promise.all(notifications.map(n => sendFCM(n)));

        return res.status(200).send('Notifications processed');
    } catch (err) {
        console.error('Error processing notifications:', err);
        return res.status(500).send(err.message);
    }
});

function createNotification(id, role, title, body) {
    return { id, role, title, body };
}

async function sendFCM(notif) {
    if (!notif.id) return;

    // 1. Get Token from Supabase (or store tokens in Firestore for faster access)
    // For this demo, let's assume we fetch the token from the record's target table
    // but since we are in a Cloud Function, it's better to fetch it once.

    // NOTE: In a REAL implementation, you'd use the admin SDK to query the fcm_token from Supabase profiles
    // For now, this is the logic structure.

    const payload = {
        notification: {
            title: notif.title,
            body: notif.body,
        },
        data: {
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
            type: 'ORDER_UPDATE',
            role: notif.role
        }
    };

    // Mock token retrieval - You should replace this with a real DB fetch
    const token = await getFCMToken(notif.id, notif.role);
    if (!token) return;

    try {
        await admin.messaging().sendToDevice(token, payload);
        console.log(`Sent ${notif.title} to ${notif.role} (${notif.id})`);
    } catch (error) {
        console.error('FCM Send Error:', error);
    }
}

const SUPABASE_URL = 'https://dxqcruvarqgnscenixzf.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = 'YOUR_SUPABASE_SERVICE_ROLE_KEY'; // MUST BE SET IN FIREBASE CONFIG

async function getFCMToken(userId, role) {
    try {
        const response = await fetch(`${SUPABASE_URL}/rest/v1/device_tokens?user_id=eq.${userId}&user_role=eq.${role}&select=device_token`, {
            headers: {
                'apikey': SUPABASE_SERVICE_ROLE_KEY,
                'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`
            }
        });
        const data = await response.json();
        if (data && data.length > 0) {
            return data[0].device_token;
        }
    } catch (error) {
        console.error("Error fetching FCM token:", error);
    }
    return null;
}
