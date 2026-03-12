CREATE OR REPLACE FUNCTION ops.get_modules()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_body text;
  v_rows text[];
  v_mod text;
  v_stats record;
  v_first_seen timestamptz;
  v_is_new boolean;
  v_total_funcs int := 0;
  v_total_tests int := 0;
  v_module_count int := 0;
BEGIN
  v_rows := ARRAY[]::text[];

  FOR v_mod IN SELECT module FROM ops._module_list()
  LOOP
    SELECT * INTO v_stats FROM ops._module_stats(v_mod);
    v_module_count := v_module_count + 1;
    v_total_funcs := v_total_funcs + v_stats.func_count;
    v_total_tests := v_total_tests + v_stats.test_count;

    -- Detect "new" modules: first activity within 7 days or no activity at all
    SELECT LEAST(
      (SELECT min(created_at) FROM workbench.agent_message
       WHERE to_module = v_mod OR from_module = v_mod),
      (SELECT min(created_at) FROM workbench.hook_log WHERE module = v_mod)
    ) INTO v_first_seen;

    v_is_new := v_first_seen IS NULL OR v_first_seen > now() - interval '7 days';

    v_rows := v_rows || ARRAY[
      '<a href="/' || pgv.esc(v_mod) || '/">' || pgv.esc(v_mod) || '</a>'
        || CASE WHEN v_is_new THEN ' ' || pgv.badge('nouveau', 'success') ELSE '' END,
      v_stats.func_count::text,
      v_stats.test_count::text,
      v_stats.msg_total::text,
      CASE WHEN v_stats.last_hook_at IS NOT NULL
        THEN to_char(v_stats.last_hook_at, 'DD/MM HH24:MI')
        ELSE '-'
      END
    ];
  END LOOP;

  IF v_module_count = 0 THEN
    RETURN pgv.empty('Aucun module', 'Deployer des modules pour les voir ici.');
  END IF;

  v_body := pgv.grid(VARIADIC ARRAY[
    pgv.stat('Modules', v_module_count::text),
    pgv.stat('Fonctions', v_total_funcs::text, 'tous modules'),
    pgv.stat('Tests', v_total_tests::text, 'pgTAP')
  ]);

  v_body := v_body || pgv.md_table(
    ARRAY['Module', 'Fonctions', 'Tests', 'Messages', 'Derniere activite'],
    v_rows
  );

  RETURN v_body;
END;
$function$;
