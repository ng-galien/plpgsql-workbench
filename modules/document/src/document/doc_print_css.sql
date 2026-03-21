CREATE OR REPLACE FUNCTION document.doc_print_css(p_doc_id text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_d document.document;
  v_w numeric;
  v_h numeric;
BEGIN
  SELECT * INTO v_d FROM document.document WHERE id = p_doc_id;
  IF v_d IS NULL THEN RETURN NULL; END IF;

  -- For landscape print formats, swap for @page size
  IF v_d.orientation = 'landscape' AND v_d.format LIKE 'A_' THEN
    v_w := v_d.height;
    v_h := v_d.width;
  ELSE
    v_w := v_d.width;
    v_h := v_d.height;
  END IF;

  RETURN '@media print {' || chr(10)
    || '  @page { size: ' || v_w::text || 'mm ' || v_h::text || 'mm; margin: 0; }' || chr(10)
    || '  nav, .pgv-nav, .pgv-toolbar, .pgv-sidebar, .pgv-toast, .pgv-breadcrumb, footer, button, [data-rpc] { display: none !important; }' || chr(10)
    || '  main { padding: 0 !important; margin: 0 !important; }' || chr(10)
    || '  .doc-print-page { width: ' || v_d.width::text || 'mm; height: ' || v_d.height::text || 'mm; break-after: page; overflow: hidden; }' || chr(10)
    || '  .doc-print-page:last-child { break-after: auto; }' || chr(10)
    || '}' || chr(10)
    || '.doc-print-page { width: ' || v_d.width::text || 'mm; height: ' || v_d.height::text || 'mm; margin: 0 auto 20px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); overflow: hidden; position: relative; }';
END;
$function$;
