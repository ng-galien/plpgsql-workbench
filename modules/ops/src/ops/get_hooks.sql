CREATE OR REPLACE FUNCTION ops.get_hooks(p_module text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_rows text[];
  v_body text;
  r record;
BEGIN
  v_rows := ARRAY[]::text[];

  FOR r IN
    SELECT h.module,
           regexp_replace(h.tool, '^mcp__plpgsql-workbench__', '') AS tool,
           left(h.action, 60) AS action,
           h.allowed,
           COALESCE(left(h.reason, 60), '') AS reason,
           to_char(h.created_at, 'DD/MM HH24:MI') AS dt
      FROM workbench.hook_log h
     WHERE (p_module IS NULL OR h.module = p_module)
     ORDER BY h.created_at DESC
     LIMIT 100
  LOOP
    v_rows := v_rows || ARRAY[
      pgv.badge(r.module, 'default'),
      r.tool,
      r.action,
      CASE WHEN r.allowed THEN pgv.badge('✓', 'success') ELSE pgv.badge('✗', 'danger') END,
      r.reason,
      r.dt
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NULL THEN
    v_body := pgv.empty('Aucun evenement hook', 'Les evenements hooks apparaitront ici.');
  ELSE
    v_body := pgv.md_table(
      ARRAY['Module', 'Tool', 'Action', 'OK', 'Raison', 'Date'],
      v_rows,
      20
    );
  END IF;

  RETURN v_body;
END;
$function$;
