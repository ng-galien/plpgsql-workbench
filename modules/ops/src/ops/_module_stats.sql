CREATE OR REPLACE FUNCTION ops._module_stats(p_module text)
 RETURNS TABLE(func_count integer, test_count integer, msg_new integer, msg_total integer, hook_deny integer, hook_total integer, last_hook_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN QUERY
  SELECT
    (SELECT count(*)::int FROM pg_proc p
       JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = p_module),
    (SELECT count(*)::int FROM pg_proc p
       JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = p_module || '_ut'),
    (SELECT count(*)::int FROM workbench.agent_message
      WHERE to_module = p_module AND status = 'new'),
    (SELECT count(*)::int FROM workbench.agent_message
      WHERE to_module = p_module OR from_module = p_module),
    (SELECT count(*)::int FROM workbench.hook_log
      WHERE module = p_module AND NOT allowed),
    (SELECT count(*)::int FROM workbench.hook_log
      WHERE module = p_module),
    (SELECT max(created_at) FROM workbench.hook_log
      WHERE module = p_module);
END;
$function$;
