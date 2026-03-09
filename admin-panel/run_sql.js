import { createClient } from '@supabase/supabase-js';
import fs from 'fs';

const supabase = createClient('https://dxqcruvarqgnscenixzf.supabase.co', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwMjQ2NzksImV4cCI6MjA4MzYwMDY3OX0.2Z_DubJZM0p_aIC_1-H_LuZIrf8twPxqLbURw3rrHxY');

async function run() {
    const sql = fs.readFileSync('../NUCLEAR_IDENTITY_MERGE_V79.sql', 'utf8');
    const { data, error } = await supabase.rpc('exec_sql', { sql });
    if (error) console.error("SQL ERROR:", error);
    else console.log("SQL SUCCESS:", data);
}

run();
