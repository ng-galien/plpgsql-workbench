CREATE OR REPLACE FUNCTION ops.post_test_run(p_schema text)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_start timestamptz;
  v_duration_ms int;
  v_passed int := 0;
  v_failed int := 0;
  v_total int := 0;
  v_line text;
BEGIN
  IF p_schema IS NULL OR p_schema = '' THEN
    RETURN '<template data-toast="error">Schema requis</template>';
  END IF;

  -- Verify schema exists
  IF NOT EXISTS(SELECT 1 FROM pg_namespace WHERE nspname = p_schema) THEN
    RETURN '<template data-toast="error">Schema ' || pgv.esc(p_schema) || ' introuvable</template>';
  END IF;

  v_start := clock_timestamp();

  -- Run pgTAP tests
  FOR v_line IN SELECT * FROM runtests(p_schema::name, ''::text)
  LOOP
    IF v_line LIKE 'ok %' THEN
      v_passed := v_passed + 1;
      v_total := v_total + 1;
    ELSIF v_line LIKE 'not ok %' THEN
      v_failed := v_failed + 1;
      v_total := v_total + 1;
    END IF;
  END LOOP;

  v_duration_ms := extract(millisecond FROM clock_timestamp() - v_start)::int
                 + extract(second FROM clock_timestamp() - v_start)::int * 1000;

  -- Record run
  INSERT INTO workbench.test_run (schema_ut, total, passed, failed, duration_ms)
  VALUES (p_schema, v_total, v_passed, v_failed, v_duration_ms);

  IF v_failed > 0 THEN
    RETURN '<template data-toast="error">' || pgv.esc(p_schema)
      || ' : ' || v_passed || ' OK, ' || v_failed || ' KO (' || v_duration_ms || ' ms)</template>';
  END IF;

  RETURN '<template data-toast="success">' || pgv.esc(p_schema)
    || ' : ' || v_passed || '/' || v_total || ' OK (' || v_duration_ms || ' ms)</template>';
END;
$function$;
