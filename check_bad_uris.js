
const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwMjQ2NzksImV4cCI6MjA4MzYwMDY3OX0.2Z_DubJZM0p_aIC_1-H_LuZIrf8twPxqLbURw3rrHxY';
const supabase = createClient(supabaseUrl, supabaseKey);

async function checkImages() {
    const { data: vendors, error: vError } = await supabase.from('vendors').select('id, name, banner_url, logo_url, image_url');
    if (vError) console.error(vError);
    else {
        console.log('--- VENDORS ---');
        vendors.forEach(v => {
            if (v.banner_url?.startsWith('file:') || v.logo_url?.startsWith('file:') || v.image_url?.startsWith('file:')) {
                console.log(`BAD IMAGE in Vendor ${v.name} (${v.id}): banner=${v.banner_url}, logo=${v.logo_url}, img=${v.image_url}`);
            }
        });
    }

    const { data: products, error: pError } = await supabase.from('products').select('id, name, image_url');
    if (pError) console.error(pError);
    else {
        console.log('--- PRODUCTS ---');
        products.forEach(p => {
            if (p.image_url?.startsWith('file:')) {
                console.log(`BAD IMAGE in Product ${p.name} (${p.id}): ${p.image_url}`);
            }
        });
    }
}

checkImages();
