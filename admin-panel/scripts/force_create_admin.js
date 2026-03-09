import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co'
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s'

const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
        autoRefreshToken: false,
        persistSession: false
    }
})

async function run() {
    const email = 'univfoods@gmail.com'
    const password = 'univfoods@123'

    console.log(`1. Checking for existing user: ${email}`)
    const { data: { users }, error: listError } = await supabase.auth.admin.listUsers()

    if (listError) {
        console.error('Error listing users:', JSON.stringify(listError, null, 2))
        // If listing fails, we can't delete safely by ID. But let's try to proceed to create anyway, assuming it might not exist.
    }

    let existingUser;
    if (users) {
        existingUser = users.find(u => u.email === email)
    }

    if (existingUser) {
        console.log(`   Found user ${existingUser.id}. Deleting...`)
        const { error: deleteError } = await supabase.auth.admin.deleteUser(existingUser.id)
        if (deleteError) {
            console.error('Error deleting user:', deleteError)
        } else {
            console.log('   User deleted.')
        }
    } else {
        console.log('   User does not exist (or list failed).')
    }

    console.log('2. Creating new verified user...')
    const { data, error: createError } = await supabase.auth.admin.createUser({
        email,
        password,
        email_confirm: true // This forces the email to be verified!
    })

    if (createError) {
        console.error('Error creating user:', createError)
    } else {
        console.log('SUCCESS! Admin user created and verified.')
        console.log('User ID:', data.user.id)
        console.log('Email:', data.user.email)
    }
}

run()
