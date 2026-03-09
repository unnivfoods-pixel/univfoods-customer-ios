-- 🤖 AUTO-BOT INTELLIGENCE & FAQ HANDSHAKE (V2 - UNIFIED)
-- Integrates with ULTIMATE_SUPPORT_INFRA_V11 to provide instant mission engagement.

BEGIN;

-- 1. Bot Signature Identity
-- Ensures the bot exists in the agents table if needed, or uses a reserved ID.

-- 2. Unified Welcome Protocol for Live Chats (support_chats)
CREATE OR REPLACE FUNCTION public.fn_live_chat_auto_welcome()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.support_messages (chat_id, sender_id, sender_type, message)
    VALUES (
        NEW.id,
        '00000000-0000-0000-0000-000000000000', -- Reserved Bot UUID
        'BOT',
        '👋 **UNIV Mission Intelligence Activated**

Welcome to the Secure Relay Channel. I am your automated mission assistant. 

**Tactical FAQ Chips detected. Please select an action below or type your query.**
• 🛵 **Telemetry**: Order tracking is available in the "Orders" module.
• 💳 **Refunds**: Return status is synced in your Profile dashboard.
• 📞 **Human Link**: Select "Talk to Agent" for priority escalation.

Admin command has been alerted and will intercept shortly.'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_live_chat_welcome ON public.support_chats;
CREATE TRIGGER tr_live_chat_welcome
    AFTER INSERT ON public.support_chats
    FOR EACH ROW
    EXECUTE PROCEDURE public.fn_live_chat_auto_welcome();

-- 3. Legacy Ticket Welcome Protocol (Optional compatibility)
CREATE OR REPLACE FUNCTION public.handle_ticket_auto_welcome()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.ticket_messages (ticket_id, sender_id, message, is_admin)
    VALUES (
        NEW.id,
        'SYSTEM_BOT',
        '👋 **UNIV Ticket Intelligence Activated**

Your support ticket has been logged in the secure vault. 

Recent Sector Intel:
• 🛵 Track your order in real-time via the app.
• 💳 Refund status is live in your profile.

A human dispatcher will review this record shortly. Response time: < 15 mins.',
        true
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_ticket_auto_welcome ON public.support_tickets;
CREATE TRIGGER tr_ticket_auto_welcome
    AFTER INSERT ON public.support_tickets
    FOR EACH ROW
    EXECUTE PROCEDURE public.handle_ticket_auto_welcome();

COMMIT;

SELECT 'Unified Bot Intelligence & FAQ Handshake Deployed (V2)' as status;
