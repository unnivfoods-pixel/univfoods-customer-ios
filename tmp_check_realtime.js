import { createClient } from '@supabase/supabase-js'
import fs from 'fs'

const supabaseUrl = 'https://ovlxmxyfscsqkqundfbt.supabase.co'
// I'll need to find the service role key or use a public one if possible, 
// but I'll try to find it in the project files.
// Actually, I can check admin-panel/src/supabase.js for the public key.

const supabaseKey = 'YOUR_KEY_HERE' // Need to find this

async function checkRealtime() {
    const supabase = createClient(supabaseUrl, supabaseKey)

    const { data: pub, error: pubError } = await supabase.rpc('check_publication')
    if (pubError) {
        console.log("Checking via direct query...")
        const { data: pubTables, error: tableError } = await supabase
            .from('pg_publication_tables')
            .select('*')
            .eq('pubname', 'supabase_realtime')

        if (tableError) {
            console.error("Error fetching publication tables:", tableError)
        } else {
            console.log("Tables in supabase_realtime publication:")
            console.table(pubTables.map(t => t.tablename))
        }
    } else {
        console.log("Publication status:", pub)
    }
}
