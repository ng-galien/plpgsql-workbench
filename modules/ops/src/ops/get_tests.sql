CREATE OR REPLACE FUNCTION ops.get_tests(p_schema text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_body text;
  v_rows text[];
  v_total_tests int := 0;
  v_total_schemas int := 0;
  v_last_passed int := 0;
  v_last_failed int := 0;
  r record;
  v_run record;
  v_history_rows text[];
BEGIN
  v_rows := ARRAY[]::text[];

  -- List all _ut schemas with test counts
  FOR r IN
    SELECT n.nspname AS schema_ut,
           count(*)::int AS test_count
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname LIKE '%\_ut' ESCAPE '\'
       AND p.proname LIKE 'test\_%' ESCAPE '\'
       AND (p_schema IS NULL OR n.nspname = p_schema || '_ut' OR n.nspname = p_schema)
     GROUP BY n.nspname
     ORDER BY n.nspname
  LOOP
    v_total_schemas := v_total_schemas + 1;
    v_total_tests := v_total_tests + r.test_count;

    -- Last run for this schema
    SELECT * INTO v_run
      FROM workbench.test_run
     WHERE schema_ut = r.schema_ut
     ORDER BY run_at DESC LIMIT 1;

    v_rows := v_rows || ARRAY[
      pgv.esc(r.schema_ut),
      r.test_count::text,
      CASE WHEN v_run.id IS NOT NULL
        THEN pgv.badge(v_run.passed::text, 'success') || ' / '
          || CASE WHEN v_run.failed > 0
               THEN pgv.badge(v_run.failed::text, 'danger')
               ELSE '0'
             END
        ELSE '-'
      END,
      CASE WHEN v_run.id IS NOT NULL
        THEN v_run.duration_ms || ' ms'
        ELSE '-'
      END,
      CASE WHEN v_run.id IS NOT NULL
        THEN to_char(v_run.run_at, 'DD/MM HH24:MI')
        ELSE '-'
      END,
      pgv.action('post_test_run', 'Lancer',
        jsonb_build_object('p_schema', r.schema_ut),
        'Lancer les tests ' || r.schema_ut || ' ?')
    ];

    IF v_run.id IS NOT NULL THEN
      v_last_passed := v_last_passed + v_run.passed;
      v_last_failed := v_last_failed + v_run.failed;
    END IF;
  END LOOP;

  IF v_total_schemas = 0 THEN
    RETURN pgv.empty('Aucun test', 'Aucun schema _ut trouve.');
  END IF;

  -- Summary stats
  v_body := pgv.grid(VARIADIC ARRAY[
    pgv.stat('Schemas', v_total_schemas::text),
    pgv.stat('Tests', v_total_tests::text, 'fonctions test_*'),
    pgv.stat('Derniers OK', v_last_passed::text, 'passed'),
    pgv.stat('Derniers KO', v_last_failed::text, 'failed')
  ]);

  v_body := v_body || pgv.md_table(
    ARRAY['Schema', 'Tests', 'Resultat', 'Duree', 'Dernier run', 'Action'],
    v_rows
  );

  -- Recent run history (last 10)
  v_history_rows := ARRAY[]::text[];
  FOR v_run IN
    SELECT * FROM workbench.test_run
     ORDER BY run_at DESC LIMIT 10
  LOOP
    v_history_rows := v_history_rows || ARRAY[
      pgv.esc(v_run.schema_ut),
      pgv.badge(v_run.passed::text, 'success') || ' / '
        || CASE WHEN v_run.failed > 0
             THEN pgv.badge(v_run.failed::text, 'danger')
             ELSE '0'
           END,
      v_run.duration_ms || ' ms',
      to_char(v_run.run_at, 'DD/MM HH24:MI:SS')
    ];
  END LOOP;

  IF array_length(v_history_rows, 1) IS NOT NULL THEN
    v_body := v_body || '<h3>Historique</h3>'
      || pgv.md_table(
        ARRAY['Schema', 'Resultat', 'Duree', 'Date'],
        v_history_rows
      );
  END IF;

  RETURN v_body;
END;
$function$;
