CREATE OR REPLACE FUNCTION docs_ut.test_document_read()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_jc jsonb;
  v_jd jsonb;
  v_j jsonb;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);
  DELETE FROM docs.document WHERE tenant_id = 'test';
  DELETE FROM docs.charter WHERE tenant_id = 'test';

  v_jc := docs.charter_create(jsonb_populate_record(NULL::docs.charter, jsonb_build_object(
    'name', 'Read Charte', 'color_bg', '#FAF6F1', 'color_main', '#2C3E2D', 'color_accent', '#C4956A',
    'color_text', '#333', 'color_text_light', '#888', 'color_border', '#eee',
    'font_heading', 'Inter', 'font_body', 'Inter'
  )));

  v_jd := docs.document_create(jsonb_populate_record(NULL::docs.document, jsonb_build_object('name', 'Read Test', 'charter_id', v_jc->>'id')));
  PERFORM docs.page_add(v_jd->>'id', 'Page 2', '<p data-id="p2">Page two</p>');

  v_j := docs.document_read(v_jd->>'id');

  RETURN NEXT ok(v_j->>'id' IS NOT NULL, 'document_read returns data');
  RETURN NEXT is(v_j->>'name', 'Read Test', 'name');
  RETURN NEXT is(v_j->>'format', 'A4', 'format');
  RETURN NEXT is(v_j->>'charter_id', v_jc->>'id', 'charter_id');
  RETURN NEXT is((v_j->>'width')::numeric, 210::numeric, 'width');

  RETURN NEXT ok(docs.document_read('nonexistent') IS NULL, 'NULL for unknown doc');

  DELETE FROM docs.document WHERE tenant_id = 'test';
  DELETE FROM docs.charter WHERE tenant_id = 'test';
END;
$function$;
