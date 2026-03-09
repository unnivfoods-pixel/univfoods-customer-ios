import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co'
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s'

const supabase = createClient(supabaseUrl, serviceKey)

async function setProperImages() {
    const { data: vendors } = await supabase.from('vendors').select('id, name');
    const images = [
        "https://images.unsplash.com/photo-1589187151053-5ec8818e661b?auto=format&fit=crop&q=80&w=1000",
        "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&q=80&w=1000"
    ];

    for (let i = 0; i < vendors.length; i++) {
        await supabase.from('vendors').update({
            image_url: images[i % images.length],
            banner_url: images[i % images.length],
            is_verified: true,
            status: 'open'
        }).eq('id', vendors[i].id);
    }
    console.log("Images updated.");
}

setProperImages();
