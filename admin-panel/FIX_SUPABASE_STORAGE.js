
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co'
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s'

const supabase = createClient(supabaseUrl, serviceKey)

async function fixStorage() {
    console.log("Checking buckets...");
    const { data: buckets, error: bucketsError } = await supabase.storage.listBuckets();

    if (bucketsError) {
        console.error("Error listing buckets:", bucketsError);
        return;
    }

    console.log("Existing buckets:", buckets.map(b => b.name));

    const bucketName = 'images';
    if (!buckets.find(b => b.name === bucketName)) {
        console.log(`Creating bucket '${bucketName}'...`);
        const { data, error } = await supabase.storage.createBucket(bucketName, {
            public: true,
            allowedMimeTypes: ['image/*'],
            fileSizeLimit: 5242880 // 5MB
        });
        if (error) {
            console.error(`Error creating bucket:`, error);
        } else {
            console.log(`Bucket '${bucketName}' created successfully.`);
        }
    } else {
        console.log(`Bucket '${bucketName}' already exists.`);
        // Ensure it's public
        const { error } = await supabase.storage.updateBucket(bucketName, { public: true });
        if (error) console.error("Error updating bucket to public:", error);
    }

    console.log("Storage fix complete.");
}

fixStorage();
