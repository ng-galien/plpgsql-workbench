CREATE OR REPLACE FUNCTION docs.get_print(p_id text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_d docs.document;
  v_charter_css text := '';
  v_print_css text;
  v_body text;
  r record;
BEGIN
  SELECT * INTO v_d FROM docs.document WHERE id = p_id AND tenant_id = current_setting('app.tenant_id', true);
  IF v_d IS NULL THEN RETURN pgv.empty(pgv.t('docs.err_not_found')); END IF;

  IF v_d.charter_id IS NOT NULL THEN
    v_charter_css := docs.charter_tokens_to_css(v_d.charter_id);
  END IF;

  v_print_css := docs.document_print_css(p_id);

  v_body := '<style>' || v_charter_css || chr(10) || v_print_css || '</style>';

  FOR r IN
    SELECT page_index, html, bg,
           COALESCE(width, v_d.width) AS w,
           COALESCE(height, v_d.height) AS h
    FROM docs.page WHERE doc_id = p_id ORDER BY page_index
  LOOP
    v_body := v_body || '<div class="doc-print-page" style="width:' || r.w::text || 'mm;height:' || r.h::text || 'mm;'
      || 'background:' || COALESCE(r.bg, v_d.bg) || '">'
      || r.html
      || '</div>';
  END LOOP;

  v_body := v_body || '<script>window.print()</script>';

  RETURN v_body;
END;
$function$;
