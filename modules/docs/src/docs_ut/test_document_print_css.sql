CREATE OR REPLACE FUNCTION docs_ut.test_document_print_css()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_j jsonb;
  v_css text;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);
  DELETE FROM docs.document WHERE tenant_id = 'test';

  v_j := docs.document_create(jsonb_populate_record(NULL::docs.document, '{"name":"Print A4"}'::jsonb));
  v_css := docs.document_print_css(v_j->>'id');
  RETURN NEXT ok(v_css LIKE '%size: 210mm 297mm%', 'A4 portrait @page size');
  RETURN NEXT ok(v_css LIKE '%break-after: page%', 'break-after present');
  RETURN NEXT ok(v_css LIKE '%.doc-print-page%', 'print page class present');

  v_j := docs.document_create(jsonb_populate_record(NULL::docs.document, '{"name":"Print A3L","format":"A3","orientation":"landscape"}'::jsonb));
  v_css := docs.document_print_css(v_j->>'id');
  RETURN NEXT ok(v_css LIKE '%size: 297mm 420mm%', 'A3 landscape @page size swapped');

  v_j := docs.document_create(jsonb_populate_record(NULL::docs.document, '{"name":"Print HD","format":"HD"}'::jsonb));
  v_css := docs.document_print_css(v_j->>'id');
  RETURN NEXT ok(v_css LIKE '%size: 1920mm 1080mm%', 'HD @page size (no swap)');

  RETURN NEXT ok(docs.document_print_css('nonexistent') IS NULL, 'NULL for unknown doc');

  DELETE FROM docs.document WHERE tenant_id = 'test';
END;
$function$;
