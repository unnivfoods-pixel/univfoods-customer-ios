-- 🚨 RPC DIAGNOSTIC
-- Run this to allow the app to fetch the latest logs.

CREATE OR REPLACE FUNCTION public.get_notification_diagnostics()
RETURNS TABLE (
    log_msg text,
    log_time timestamptz,
    notif_user text,
    notif_title text,
    notif_time timestamptz
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        l.msg, l.created_at,
        n.user_id::text, n.title, n.created_at
    FROM public.debug_logs l
    LEFT JOIN public.notifications n ON n.created_at >= l.created_at - interval '1 second'
    ORDER BY l.created_at DESC
    LIMIT 10;
END;
$$ LANGUAGE plpgsql;
