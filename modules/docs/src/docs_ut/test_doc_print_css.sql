CREATE OR REPLACE FUNCTION docs_ut.test_doc_print_css()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id text;
  v_css text;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);
  DELETE FROM docs.document WHERE tenant_id = 'test';

  -- A4 portrait
  v_id := docs.doc_create('Print A4');
  v_css := docs.doc_print_css(v_id);
  RETURN NEXT ok(v_css LIKE '%size: 210mm 297mm%', 'A4 portrait @page size');
  RETURN NEXT ok(v_css LIKE '%break-after: page%', 'break-after present');
  RETURN NEXT ok(v_css LIKE '%.doc-print-page%', 'print page class present');

  -- A3 landscape
  v_id := docs.doc_create('Print A3L', p_format := 'A3', p_orientation := 'landscape');
  v_css := docs.doc_print_css(v_id);
  -- landscape A3: doc w=420 h=297, @page should be 297mm 420mm (swapped back)
  RETURN NEXT ok(v_css LIKE '%size: 297mm 420mm%', 'A3 landscape @page size swapped');

  -- HD (no swap)
  v_id := docs.doc_create('Print HD', p_format := 'HD');
  v_css := docs.doc_print_css(v_id);
  RETURN NEXT ok(v_css LIKE '%size: 1920mm 1080mm%', 'HD @page size (no swap)');

  -- Not found
  RETURN NEXT ok(docs.doc_print_css('nonexistent') IS NULL, 'NULL for unknown doc');

  DELETE FROM docs.document WHERE tenant_id = 'test';
END;
$function$;
