CREATE OR REPLACE FUNCTION docs_ut.test_document_read()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_d docs.document;
  v_c docs.charte;
  v_r docs.document;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);
  DELETE FROM docs.document WHERE tenant_id = 'test';
  DELETE FROM docs.charte WHERE tenant_id = 'test';

  v_c := docs.charte_create(jsonb_populate_record(NULL::docs.charte, jsonb_build_object(
    'name', 'Read Charte', 'color_bg', '#FAF6F1', 'color_main', '#2C3E2D', 'color_accent', '#C4956A',
    'color_text', '#333', 'color_text_light', '#888', 'color_border', '#eee',
    'font_heading', 'Inter', 'font_body', 'Inter'
  )));

  v_d := docs.document_create(jsonb_populate_record(NULL::docs.document, jsonb_build_object('name', 'Read Test', 'charte_id', v_c.id)));
  PERFORM docs.page_add(v_d.id, 'Page 2', '<p data-id="p2">Page two</p>');

  v_r := docs.document_read(v_d.id);

  RETURN NEXT ok(v_r.id IS NOT NULL, 'document_read returns data');
  RETURN NEXT is(v_r.name, 'Read Test', 'name');
  RETURN NEXT is(v_r.format, 'A4', 'format');
  RETURN NEXT is(v_r.charte_id, v_c.id, 'charte_id');
  RETURN NEXT is(v_r.width, 210::numeric, 'width');

  -- Not found
  RETURN NEXT ok((docs.document_read('nonexistent')).id IS NULL, 'NULL for unknown doc');

  DELETE FROM docs.document WHERE tenant_id = 'test';
  DELETE FROM docs.charte WHERE tenant_id = 'test';
END;
$function$;
