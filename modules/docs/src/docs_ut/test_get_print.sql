CREATE OR REPLACE FUNCTION docs_ut.test_get_print()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_jc jsonb;
  v_jd jsonb;
  v_html text;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);
  DELETE FROM docs.document WHERE tenant_id = 'test';
  DELETE FROM docs.charter WHERE tenant_id = 'test';

  v_jc := docs.charter_create(jsonb_populate_record(NULL::docs.charter, jsonb_build_object(
    'name', 'Print Charte', 'color_bg', '#FAF6F1', 'color_main', '#2C3E2D', 'color_accent', '#C4956A',
    'color_text', '#333', 'color_text_light', '#888', 'color_border', '#eee',
    'font_heading', 'Inter', 'font_body', 'Inter'
  )));

  v_jd := docs.document_create(jsonb_populate_record(NULL::docs.document, jsonb_build_object('name', 'Print Doc', 'charter_id', v_jc->>'id')));
  PERFORM docs.page_set_html(v_jd->>'id', 0, '<p data-id="p1">Page 1</p>');
  PERFORM docs.page_add(v_jd->>'id', 'Page 2', '<p data-id="p2">Page 2</p>');

  v_html := docs.get_print(v_jd->>'id');

  RETURN NEXT ok(v_html LIKE '%--charte-color-bg%', 'charte CSS present');
  RETURN NEXT ok(v_html LIKE '%@media print%', 'print CSS present');
  RETURN NEXT ok(v_html LIKE '%doc-print-page%', 'page containers present');
  RETURN NEXT ok(v_html LIKE '%Page 1%', 'page 1 content');
  RETURN NEXT ok(v_html LIKE '%Page 2%', 'page 2 content');
  RETURN NEXT ok(v_html LIKE '%window.print()%', 'auto-print script');

  DELETE FROM docs.document WHERE tenant_id = 'test';
  DELETE FROM docs.charter WHERE tenant_id = 'test';
END;
$function$;
