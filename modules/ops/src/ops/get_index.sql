CREATE OR REPLACE FUNCTION ops.get_index()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_body text;
  v_cards text[];
  v_timeline_rows text[];
  v_mod text;
  v_stats record;
  v_session_status text;
  v_active_count int;
  v_msg_new_total int;
  v_hook_deny_today int;
  v_module_count int;
  r record;
BEGIN
  -- Global stats
  SELECT count(*)::int INTO v_active_count
    FROM workbench.agent_session WHERE status = 'running';

  SELECT count(*)::int INTO v_msg_new_total
    FROM workbench.agent_message WHERE status = 'new';

  SELECT count(*)::int INTO v_hook_deny_today
    FROM workbench.hook_log
   WHERE NOT allowed AND created_at >= date_trunc('day', now());

  SELECT count(*)::int INTO v_module_count
    FROM ops._module_list();

  v_body := pgv.grid(VARIADIC ARRAY[
    pgv.stat('Agents actifs', v_active_count::text),
    pgv.stat('Messages non lus', v_msg_new_total::text),
    pgv.stat('Hooks bloques', v_hook_deny_today::text, 'aujourd''hui'),
    pgv.stat('Modules', v_module_count::text)
  ]);

  -- Agent cards
  v_cards := ARRAY[]::text[];
  FOR v_mod IN SELECT module FROM ops._module_list()
  LOOP
    SELECT * INTO v_stats FROM ops._module_stats(v_mod);

    -- Check session status
    SELECT s.status INTO v_session_status
      FROM workbench.agent_session s
     WHERE s.module = v_mod AND s.status = 'running'
     ORDER BY s.started_at DESC LIMIT 1;

    v_cards := v_cards || pgv.card(
      '<a href="/' || pgv.esc(v_mod) || '/">' || pgv.esc(v_mod) || '</a> '
        || pgv.badge(
          COALESCE(v_session_status, 'idle'),
          CASE WHEN v_session_status = 'running' THEN 'success' ELSE 'default' END
        ),
      pgv.grid(VARIADIC ARRAY[
        pgv.stat('Fonctions', v_stats.func_count::text),
        pgv.stat('Tests', v_stats.test_count::text),
        pgv.stat('Messages', v_stats.msg_new::text, 'non lus'),
        pgv.stat('Hook deny', v_stats.hook_deny::text)
      ]),
      '<a href="' || pgv.call_ref('get_agent', jsonb_build_object('p_module', v_mod)) || '">Agent</a>'
        || ' · <a href="/' || pgv.esc(v_mod) || '/">Frontend</a>'
    );
  END LOOP;

  IF array_length(v_cards, 1) IS NULL THEN
    v_body := v_body || pgv.empty('Aucun module', 'Deployer des modules pour les voir ici.');
  ELSE
    v_body := v_body || '<div class="ops-agent-grid">' || array_to_string(v_cards, '') || '</div>';
  END IF;

  -- Recent events timeline
  v_timeline_rows := ARRAY[]::text[];
  FOR r IN SELECT * FROM ops._recent_events(20)
  LOOP
    v_timeline_rows := v_timeline_rows || ARRAY[
      pgv.badge(r.event_type, CASE r.event_type WHEN 'message' THEN 'info' ELSE 'warning' END),
      pgv.badge(r.module, 'default'),
      r.detail,
      to_char(r.created_at, 'DD/MM HH24:MI')
    ];
  END LOOP;

  IF array_length(v_timeline_rows, 1) IS NOT NULL THEN
    v_body := v_body || '<h3>Activite recente</h3>'
      || pgv.md_table(
        ARRAY['Type', 'Module', 'Detail', 'Date'],
        v_timeline_rows
      );
  END IF;

  RETURN v_body;
END;
$function$;
