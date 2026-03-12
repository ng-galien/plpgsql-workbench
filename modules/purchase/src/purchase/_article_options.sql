CREATE OR REPLACE FUNCTION purchase._article_options()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_stock_exists boolean;
  v_html text := '<option value="">— aucun —</option>';
  r record;
BEGIN
  SELECT EXISTS(SELECT 1 FROM pg_namespace WHERE nspname = 'stock') INTO v_stock_exists;
  IF NOT v_stock_exists THEN RETURN v_html; END IF;

  FOR r IN EXECUTE 'SELECT id, reference, designation FROM stock.article WHERE active = true ORDER BY reference'
  LOOP
    v_html := v_html || format('<option value="%s">%s — %s</option>', r.id, pgv.esc(r.reference), pgv.esc(r.designation));
  END LOOP;

  RETURN v_html;
END;
$function$;
