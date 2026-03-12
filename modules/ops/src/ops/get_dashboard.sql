CREATE OR REPLACE FUNCTION ops.get_dashboard()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_body text;
  v_rows text[];
  v_mod text;
  v_stats record;
  v_total_funcs int := 0;
  v_total_tests int := 0;
  v_total_pending int := 0;
  v_total_hook_deny int := 0;
  v_last_hook text;
BEGIN
  v_rows := ARRAY[]::text[];

  FOR v_mod IN SELECT module FROM ops._module_list()
  LOOP
    SELECT * INTO v_stats FROM ops._module_stats(v_mod);

    v_total_funcs := v_total_funcs + v_stats.func_count;
    v_total_tests := v_total_tests + v_stats.test_count;
    v_total_pending := v_total_pending + v_stats.msg_new;
    v_total_hook_deny := v_total_hook_deny + v_stats.hook_deny;

    v_last_hook := CASE
      WHEN v_stats.last_hook_at IS NOT NULL
        THEN to_char(v_stats.last_hook_at, 'DD/MM HH24:MI')
      ELSE '-'
    END;

    v_rows := v_rows || ARRAY[
      pgv.esc(v_mod),
      v_stats.func_count::text,
      v_stats.test_count::text,
      CASE WHEN v_stats.msg_new > 0
        THEN pgv.badge(v_stats.msg_new::text, 'warning')
        ELSE '0'
      END,
      CASE WHEN v_stats.hook_deny > 0
        THEN pgv.badge(v_stats.hook_deny::text, 'danger')
        ELSE '0'
      END || ' / ' || v_stats.hook_total::text,
      v_last_hook
    ];
  END LOOP;

  -- Top stats
  v_body := pgv.grid(VARIADIC ARRAY[
    pgv.stat('Fonctions', v_total_funcs::text, 'tous modules'),
    pgv.stat('Tests', v_total_tests::text, 'pgTAP'),
    pgv.stat('Messages pending', v_total_pending::text),
    pgv.stat('Hooks bloques', v_total_hook_deny::text, 'total')
  ]);

  -- Module detail table
  IF array_length(v_rows, 1) IS NULL THEN
    v_body := v_body || pgv.empty('Aucun module', 'Deployer des modules pour les voir ici.');
  ELSE
    v_body := v_body || pgv.md_table(
      ARRAY['Module', 'Fonctions', 'Tests', 'Pending', 'Hooks deny', 'Dernier hook'],
      v_rows
    );
  END IF;

  RETURN v_body;
END;
$function$;
