
import { createClient } from '@supabase/supabase-js'
import fs from 'fs'

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co'
const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwMjQ2NzksImV4cCI6MjA4MzYwMDY3OX0.2Z_DubJZM0p_aIC_1-H_LuZIrf8twPxqLbURw3rrHxY'

const supabase = createClient(supabaseUrl, anonKey)

async function testUpload() {
    console.log("Testing upload with anon key...");
    const fileName = `test-${Date.now()}.txt`;
    const { data, error } = await supabase.storage
        .from('images')
        .upload(`uploads/${fileName}`, 'test content', {
            contentType: 'text/plain'
        });

    if (error) {
        console.error("Upload failed with anon key:", error);
    } else {
        console.log("Upload successful with anon key!", data);
    }
}

testUpload();
