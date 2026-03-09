
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co'
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s'

const supabase = createClient(supabaseUrl, serviceKey)

const categories = [
    {
        "name": "Biryani",
        "image_url": "https://img.freepik.com/free-photo/gourmet-chicken-biryani-with-steaming-basmati-rice-generated-by-ai_188544-15525.jpg",
        "priority": 100,
        "is_active": true
    },
    {
        "name": "Burger",
        "image_url": "https://img.freepik.com/free-photo/delicious-quality-burger-with-vegetables_23-2150867844.jpg",
        "priority": 90,
        "is_active": true
    },
    {
        "name": "Pizza",
        "image_url": "https://img.freepik.com/free-photo/fresh-baked-pizza-with-tasty-toppings-generated-by-ai_188544-15411.jpg",
        "priority": 80,
        "is_active": true
    },
    {
        "name": "North Indian",
        "image_url": "https://img.freepik.com/free-photo/traditional-indian-food-thali-with-dal-flatbread-rice-chicken-curry_123827-21783.jpg",
        "priority": 70,
        "is_active": true
    },
    {
        "name": "South Indian",
        "image_url": "https://img.freepik.com/free-photo/south-indian-food-dosa-idli-sambhar-chutney-white-background_123827-21764.jpg",
        "priority": 60,
        "is_active": true
    },
    {
        "name": "Desserts",
        "image_url": "https://img.freepik.com/free-photo/delicious-cake-with-chocolate-berries_23-2150727653.jpg",
        "priority": 50,
        "is_active": true
    }
];

async function seedCategories() {
    console.log("Seeding categories...");
    const { error } = await supabase.from('categories').insert(categories);
    if (error) {
        console.error("SEED ERROR:", error.message);
    } else {
        console.log("SUCCESSfully seeded 6 categories!");
    }
}

seedCategories();
