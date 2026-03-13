CREATE OR REPLACE FUNCTION workbench.api_hooks(p_module text DEFAULT NULL::text)
 RETURNS TABLE(id integer, module text, tool text, action text, allowed boolean, reason text, created_at timestamp with time zone)
 LANGUAGE sql
 STABLE
AS $function$
  SELECT h.id, h.module, h.tool, h.action, h.allowed, h.reason, h.created_at
    FROM workbench.hook_log h
   WHERE p_module IS NULL OR h.module = p_module
   ORDER BY h.created_at DESC
   LIMIT 100;
$function$;
