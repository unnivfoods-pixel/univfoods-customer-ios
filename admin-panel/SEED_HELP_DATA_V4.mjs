import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://dxqcruvarqgnscenixzf.supabase.co';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4cWNydXZhcnFnbnNjZW5peHpmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2ODAyNDY3OSwiZXhwIjoyMDgzNjAwNjc5fQ.qIQG3723MjMu9YMLoRQXGepqCzllJWHFiLLcOKV6O3s';

const supabase = createClient(supabaseUrl, serviceKey);

async function seedData() {
    console.log(">>> Seeding Help & Support Data (V4)...");

    try {
        // 1. Seed FAQs
        const faqs = [
            { category: 'Orders', question: 'How to track my order?', answer: 'Go to the Orders section and tap on the active order to see real-time tracking.', active_status: true },
            { category: 'Payments', question: 'Is Cash on Delivery available?', answer: 'Yes, COD is available for most locations. Choose it at checkout.', active_status: true },
            { category: 'Refunds', question: 'How long does a refund take?', answer: 'Refunds are processed within 5-7 business days to your original payment method.', active_status: true },
            { category: 'Account', question: 'How to delete my account?', answer: 'You can request account deletion via the Help & Support chat.', active_status: true },
            { category: 'Safety', question: 'What to do in an emergency?', answer: 'Use the Safety Emergency button in the Help & Support screen for immediate assistance.', active_status: true }
        ];

        console.log(">>> Upserting FAQs...");
        const { error: faqError } = await supabase.from('faqs').upsert(faqs);
        if (faqError) console.error("FAQ Error:", faqError.message);

        // 2. Seed Legal Documents
        const legalDoc = {
            type: 'TERMS_CONDITIONS',
            title: 'Terms & Conditions',
            content: 'Welcome to UNIV. By using our service, you agree to the following terms...',
            version: '1.0',
            is_active: true,
            published_at: new Date().toISOString()
        };

        console.log(">>> Upserting Legal Doc...");
        const { error: legalError } = await supabase.from('legal_documents').upsert(legalDoc);
        if (legalError) console.error("Legal Error:", legalError.message);

        // 3. Seed App Settings (System Config)
        const systemConfig = {
            platformName: 'UNIV Foods',
            supportEmail: 'support@univfoods.in',
            supportPhone: '+919940407600',
            emergencyPhone: '100',
            currency: 'INR (₹)',
            maintenanceMode: false,
            deliveryRadius: 15,
            codEnabled: true,
            maxCodValue: 2000,
            autoAssignRiders: true
        };

        console.log(">>> Upserting System Config in app_settings...");
        const { error: settingsError } = await supabase.from('app_settings').upsert({
            key: 'system_config',
            value: systemConfig,
            updated_at: new Date().toISOString()
        });
        if (settingsError) console.error("Settings Error:", settingsError.message);

        console.log(">>> Seeding V4 Complete!");
    } catch (e) {
        console.error(">>> SEEDING FAILED:", e);
    }
}

seedData();
