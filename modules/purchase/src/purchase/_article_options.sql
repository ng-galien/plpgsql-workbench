CREATE OR REPLACE FUNCTION purchase._article_options()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text := '<option value="">— aucun —</option>';
  v_opts text;
  v_sql text;
  r record;
BEGIN
  -- Priority: catalog > stock > empty
  SELECT 'SELECT ' || n.nspname || '.article_options()'
    INTO v_sql
    FROM pg_namespace n
    JOIN pg_proc p ON p.pronamespace = n.oid AND p.proname = 'article_options'
   WHERE n.nspname = 'catalog';
  IF v_sql IS NOT NULL THEN
    EXECUTE v_sql INTO v_opts;
    RETURN v_html || coalesce(v_opts, '');
  END IF;

  IF EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'stock') THEN
    FOR r IN EXECUTE 'SELECT id, reference, designation FROM stock.article WHERE active = true ORDER BY reference'
    LOOP
      v_html := v_html || format('<option value="%s">%s — %s</option>', r.id, pgv.esc(r.reference), pgv.esc(r.designation));
    END LOOP;
  END IF;

  RETURN v_html;
END;
$function$;
