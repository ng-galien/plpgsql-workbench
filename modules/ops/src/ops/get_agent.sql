CREATE OR REPLACE FUNCTION ops.get_agent(p_module text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_body text;
  v_stats record;
  v_msg_rows text[];
  v_hook_rows text[];
  r record;
  v_type_variant text;
  v_status_variant text;
BEGIN
  -- Breadcrumb
  v_body := pgv.breadcrumb(VARIADIC ARRAY['Dashboard', '/', p_module]);

  -- Stats
  SELECT * INTO v_stats FROM ops._module_stats(p_module);
  v_body := v_body || pgv.grid(VARIADIC ARRAY[
    pgv.stat('Fonctions', v_stats.func_count::text),
    pgv.stat('Tests', v_stats.test_count::text),
    pgv.stat('Messages', v_stats.msg_new::text || ' / ' || v_stats.msg_total::text, 'new / total'),
    pgv.stat('Hooks bloques', v_stats.hook_deny::text || ' / ' || v_stats.hook_total::text)
  ]);

  -- Terminal container (auto-connects via x-init)
  v_body := v_body
    || '<div x-data="opsTerminal" data-module="' || pgv.esc(p_module) || '" x-init="$nextTick(() => connect())" class="ops-terminal ops-terminal--detail">'
    || '<div x-ref="terminal"></div>'
    || '<div x-show="!connected" class="ops-terminal-status">Connexion...</div>'
    || '</div>';

  -- Messages for this module (last 20)
  v_msg_rows := ARRAY[]::text[];
  FOR r IN
    SELECT m.id, m.from_module, m.to_module, m.msg_type, m.subject, m.status,
           to_char(m.created_at, 'DD/MM HH24:MI') AS dt
      FROM workbench.agent_message m
     WHERE m.from_module = p_module OR m.to_module = p_module
     ORDER BY m.created_at DESC
     LIMIT 20
  LOOP
    v_type_variant := CASE r.msg_type
      WHEN 'feature_request' THEN 'info'
      WHEN 'bug_report' THEN 'danger'
      WHEN 'issue_report' THEN 'danger'
      WHEN 'question' THEN 'warning'
      ELSE 'default'
    END;
    v_status_variant := CASE r.status
      WHEN 'new' THEN 'warning'
      WHEN 'acknowledged' THEN 'info'
      WHEN 'resolved' THEN 'success'
      ELSE 'default'
    END;
    v_msg_rows := v_msg_rows || ARRAY[
      pgv.badge(r.from_module, 'default'),
      pgv.badge(r.to_module, 'default'),
      pgv.badge(r.msg_type, v_type_variant),
      pgv.esc(r.subject),
      pgv.badge(r.status, v_status_variant),
      r.dt
    ];
  END LOOP;

  -- Hooks for this module (last 20)
  v_hook_rows := ARRAY[]::text[];
  FOR r IN
    SELECT regexp_replace(h.tool, '^mcp__plpgsql-workbench__', '') AS tool,
           left(h.action, 60) AS action,
           h.allowed,
           to_char(h.created_at, 'DD/MM HH24:MI') AS dt
      FROM workbench.hook_log h
     WHERE h.module = p_module
     ORDER BY h.created_at DESC
     LIMIT 20
  LOOP
    v_hook_rows := v_hook_rows || ARRAY[
      pgv.esc(r.tool),
      pgv.esc(r.action),
      CASE WHEN r.allowed THEN pgv.badge('✓', 'success') ELSE pgv.badge('✗', 'danger') END,
      r.dt
    ];
  END LOOP;

  -- Tabs: Messages + Hooks
  v_body := v_body || pgv.tabs(VARIADIC ARRAY[
    'Messages',
    CASE WHEN array_length(v_msg_rows, 1) IS NULL
      THEN pgv.empty('Aucun message')
      ELSE pgv.md_table(ARRAY['De', 'A', 'Type', 'Sujet', 'Status', 'Date'], v_msg_rows)
    END,
    'Hooks',
    CASE WHEN array_length(v_hook_rows, 1) IS NULL
      THEN pgv.empty('Aucun evenement hook')
      ELSE pgv.md_table(ARRAY['Tool', 'Action', 'OK', 'Date'], v_hook_rows)
    END
  ]);

  RETURN v_body;
END;
$function$;
