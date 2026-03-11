CREATE OR REPLACE FUNCTION pgv_qa.get_diagnostics()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_body text := '';
  v_rec record;
BEGIN
  FOR v_rec IN
    SELECT e.value->>'href' AS href, e.value->>'label' AS label
    FROM jsonb_array_elements(pgv_qa.nav_items()) e
  LOOP
    v_body := v_body || '<section><h4>' || pgv.esc(v_rec.label) || ' (' || pgv.esc(v_rec.href) || ')</h4>'
      || pgv.lazy('lazy_diagnose', jsonb_build_object('p_path', v_rec.href))
      || '</section>';
  END LOOP;
  RETURN v_body;
END;
$function$;
