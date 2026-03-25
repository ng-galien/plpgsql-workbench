CREATE OR REPLACE FUNCTION docs_ut.test_document_create()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_j jsonb;
  v_jc jsonb;
  v_r record;
  v_page_cnt int;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);
  DELETE FROM docs.document WHERE tenant_id = 'test';
  DELETE FROM docs.charte WHERE tenant_id = 'test';

  -- A4 portrait
  v_j := docs.document_create(jsonb_populate_record(NULL::docs.document, '{"name":"Test A4"}'::jsonb));
  SELECT * INTO v_r FROM docs.document WHERE id = v_j->>'id';
  RETURN NEXT is(v_r.width, 210::numeric, 'A4 width = 210');
  RETURN NEXT is(v_r.height, 297::numeric, 'A4 height = 297');
  RETURN NEXT is(v_r.format, 'A4', 'format stored');
  RETURN NEXT is(v_r.orientation, 'portrait', 'orientation default portrait');
  RETURN NEXT is(v_j->>'slug', 'general-test-a4', 'slug from category+name');

  SELECT count(*)::int INTO v_page_cnt FROM docs.page WHERE doc_id = v_j->>'id';
  RETURN NEXT is(v_page_cnt, 1, 'first page auto-created');

  -- A3 landscape
  v_j := docs.document_create(jsonb_populate_record(NULL::docs.document, '{"name":"Test A3 L","format":"A3","orientation":"landscape"}'::jsonb));
  SELECT * INTO v_r FROM docs.document WHERE id = v_j->>'id';
  RETURN NEXT is(v_r.width, 420::numeric, 'A3 landscape width = 420');
  RETURN NEXT is(v_r.height, 297::numeric, 'A3 landscape height = 297');

  -- HD
  v_j := docs.document_create(jsonb_populate_record(NULL::docs.document, '{"name":"Test HD","format":"HD"}'::jsonb));
  SELECT * INTO v_r FROM docs.document WHERE id = v_j->>'id';
  RETURN NEXT is(v_r.width, 1920::numeric, 'HD width = 1920');
  RETURN NEXT is(v_r.height, 1080::numeric, 'HD height = 1080');

  -- With charte
  v_jc := docs.charte_create(jsonb_populate_record(NULL::docs.charte, jsonb_build_object(
    'name', 'Test DC', 'color_bg', '#fff', 'color_main', '#000', 'color_accent', '#f00',
    'color_text', '#333', 'color_text_light', '#888', 'color_border', '#eee',
    'font_heading', 'Inter', 'font_body', 'Inter'
  )));
  v_j := docs.document_create(jsonb_populate_record(NULL::docs.document, jsonb_build_object('name', 'With Charte', 'charte_id', v_jc->>'id')));
  SELECT * INTO v_r FROM docs.document WHERE id = v_j->>'id';
  RETURN NEXT is(v_r.charte_id, v_jc->>'id', 'charte linked');

  DELETE FROM docs.document WHERE tenant_id = 'test';
  DELETE FROM docs.charte WHERE tenant_id = 'test';
END;
$function$;
