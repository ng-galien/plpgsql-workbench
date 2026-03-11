CREATE OR REPLACE FUNCTION ops._recent_events(p_limit integer DEFAULT 20)
 RETURNS TABLE(event_type text, module text, detail text, created_at timestamp with time zone)
 LANGUAGE sql
 STABLE
AS $function$
  (
    SELECT 'message'::text,
           m.from_module || ' -> ' || m.to_module,
           m.msg_type || ': ' || m.subject,
           m.created_at
      FROM workbench.agent_message m
     ORDER BY m.created_at DESC
     LIMIT p_limit
  )
  UNION ALL
  (
    SELECT 'hook'::text,
           h.module,
           regexp_replace(h.tool, '^mcp__plpgsql-workbench__', '')
             || CASE WHEN h.action <> '' THEN ' — ' || left(h.action, 60) ELSE '' END
             || CASE WHEN h.allowed THEN '' ELSE ' [BLOCKED]' END,
           h.created_at
      FROM workbench.hook_log h
     ORDER BY h.created_at DESC
     LIMIT p_limit
  )
  ORDER BY created_at DESC
  LIMIT p_limit;
$function$;
