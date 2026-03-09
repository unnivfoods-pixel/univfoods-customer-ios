
const { createClient } = require('@supabase/supabase-js');
const SUPABASE_URL = 'https://dxqcruvarqgnscenixzf.supabase.co';
const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwMjQ2NzksImV4cCI6MjA4MzYwMDY3OX0.2Z_DubJZM0p_aIC_1-H_LuZIrf8twPxqLbURw3rrHxY';
const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

async function check() {
    const { data: products, error } = await supabase.from('products').select('*');
    if (error) {
        console.error(error);
        return;
    }
    console.log('PRODUCTS_COUNT:', products.length);
    if (products.length > 0) {
        console.log('CATEGORIES:', [...new Set(products.map(p => p.category))]);
        console.log('FIRST_PRODUCT:', JSON.stringify(products[0], null, 2));
    } else {
        console.log('NO_PRODUCTS_FOUND');
    }
}

check();
