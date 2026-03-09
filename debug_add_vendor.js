const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s';
const supabase = createClient(supabaseUrl, serviceKey);

async function debugAddVendor() {
    const payload = {
        name: "Debug Vendor",
        address: "Debug Address",
        phone: "1234567890",
        manager: "Debug Manager",
        cuisine_type: "Debug Cuisine",
        open_time: "09:00",
        close_time: "22:00",
        banner_url: "https://example.com/banner.jpg",
        is_pure_veg: false,
        has_offers: false,
        latitude: 9.51,
        longitude: 77.63,
        delivery_radius_km: 15,
        status: 'ONLINE',
        rating: 5.0,
        email: "debug@example.com"
    };

    console.log('Attempting to insert vendor...');
    const { data, error } = await supabase.from('vendors').insert([payload]);

    if (error) {
        console.error('INSERT ERROR:', error);
    } else {
        console.log('SUCCESS:', data);
    }
}

debugAddVendor();
