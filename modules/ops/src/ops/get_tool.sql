CREATE OR REPLACE FUNCTION ops.get_tool(p_name text)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_body text;
  v_tool record;
  v_pack text;
  v_rows text[];
  v_total_calls int;
  v_total_blocked int;
  v_mcp_name text;
  v_param record;
  v_param_rows text[];
  r record;
BEGIN
  -- Fetch tool with metadata
  SELECT * INTO v_tool FROM workbench.toolbox_tool WHERE tool_name = p_name;
  IF v_tool IS NULL THEN
    RETURN pgv.empty('Tool "' || pgv.esc(p_name) || '" introuvable');
  END IF;

  -- Pack
  v_pack := CASE
    WHEN p_name LIKE 'pg\_%' ESCAPE '\' THEN 'plpgsql'
    WHEN p_name LIKE 'fs\_%' ESCAPE '\' THEN 'docstore'
    WHEN p_name LIKE 'gmail\_%' ESCAPE '\' THEN 'google'
    WHEN p_name LIKE 'doc\_%' ESCAPE '\' THEN 'docman'
    WHEN p_name LIKE 'ws\_%' ESCAPE '\' THEN 'plpgsql'
    ELSE 'other'
  END;

  v_mcp_name := 'mcp__plpgsql-workbench__' || p_name;

  -- Global stats for this tool
  SELECT count(*)::int, count(*) FILTER (WHERE NOT allowed)::int
    INTO v_total_calls, v_total_blocked
    FROM workbench.hook_log
   WHERE tool = v_mcp_name;

  -- Breadcrumb
  v_body := pgv.breadcrumb(VARIADIC ARRAY['Tools', '/ops/tools', pgv.esc(p_name)]);

  -- Header
  v_body := v_body || pgv.grid(VARIADIC ARRAY[
    pgv.stat('Pack', v_pack),
    pgv.stat('Appels', v_total_calls::text, 'total traces'),
    pgv.stat('Bloques', v_total_blocked::text, 'par hooks')
  ]);

  -- Description (from MCP registry via sync-tools)
  IF v_tool.description IS NOT NULL THEN
    v_body := v_body || pgv.card('Description', '<p>' || pgv.esc(v_tool.description) || '</p>', NULL);
  END IF;

  -- Parameters (from input_schema via sync-tools)
  IF v_tool.input_schema IS NOT NULL AND v_tool.input_schema->'properties' IS NOT NULL THEN
    v_param_rows := ARRAY[]::text[];
    FOR v_param IN
      SELECT
        k.key AS param_name,
        COALESCE(k.value->>'type', 'any') AS param_type,
        COALESCE(k.value->>'description', '-') AS param_desc,
        CASE WHEN v_tool.input_schema->'required' @> to_jsonb(k.key)
          THEN pgv.badge('requis', 'danger')
          ELSE pgv.badge('optionnel', 'default')
        END AS required_badge
      FROM jsonb_each(v_tool.input_schema->'properties') AS k
      ORDER BY k.key
    LOOP
      v_param_rows := v_param_rows || ARRAY[
        '<code>' || pgv.esc(v_param.param_name) || '</code>',
        pgv.badge(v_param.param_type, 'info'),
        v_param.required_badge,
        pgv.esc(v_param.param_desc)
      ];
    END LOOP;

    IF array_length(v_param_rows, 1) IS NOT NULL THEN
      v_body := v_body || '<h3>Parametres</h3>'
        || pgv.md_table(ARRAY['Nom', 'Type', 'Requis', 'Description'], v_param_rows);
    END IF;
  END IF;

  -- Usage by module
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT module,
           count(*)::int AS calls,
           count(*) FILTER (WHERE allowed)::int AS allowed,
           count(*) FILTER (WHERE NOT allowed)::int AS blocked,
           max(created_at) AS last_used
      FROM workbench.hook_log
     WHERE tool = v_mcp_name
     GROUP BY module
     ORDER BY count(*) DESC
  LOOP
    v_rows := v_rows || ARRAY[
      pgv.badge(r.module, 'default'),
      r.calls::text,
      r.allowed::text,
      CASE WHEN r.blocked > 0
        THEN pgv.badge(r.blocked::text, 'danger')
        ELSE '0'
      END,
      to_char(r.last_used, 'DD/MM HH24:MI')
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NOT NULL THEN
    v_body := v_body || '<h3>Utilisation par module</h3>'
      || pgv.md_table(
        ARRAY['Module', 'Appels', 'OK', 'Bloques', 'Dernier'],
        v_rows
      );
  ELSE
    v_body := v_body || pgv.empty('Aucun appel trace', 'Ce tool n''a pas encore ete utilise via les hooks.');
  END IF;

  -- Recent calls (last 20)
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT module, action, allowed, reason, created_at
      FROM workbench.hook_log
     WHERE tool = v_mcp_name
     ORDER BY created_at DESC
     LIMIT 20
  LOOP
    v_rows := v_rows || ARRAY[
      pgv.badge(r.module, 'default'),
      COALESCE(pgv.esc(r.action), '-'),
      CASE WHEN r.allowed
        THEN pgv.badge('OK', 'success')
        ELSE pgv.badge('BLOQUE', 'danger')
      END,
      COALESCE(pgv.esc(left(r.reason, 60)), '-'),
      to_char(r.created_at, 'DD/MM HH24:MI')
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NOT NULL THEN
    v_body := v_body || '<h3>Appels recents</h3>'
      || pgv.md_table(
        ARRAY['Module', 'Action', 'Status', 'Raison', 'Date'],
        v_rows
      );
  END IF;

  RETURN v_body;
END;
$function$;
