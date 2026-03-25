CREATE OR REPLACE FUNCTION workbench.log_hook(p_module text, p_tool text, p_action text, p_allowed boolean, p_reason text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
AS $function$
  INSERT INTO workbench.hook_log (module, tool, action, allowed, reason)
    VALUES (p_module, p_tool, p_action, p_allowed, p_reason);
$function$;
