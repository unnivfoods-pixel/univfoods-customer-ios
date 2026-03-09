SELECT 
    trigger_name, 
    event_object_table as table_name, 
    action_statement as definition
FROM information_schema.triggers
WHERE action_statement LIKE '%sender_role%';
