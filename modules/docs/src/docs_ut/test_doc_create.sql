CREATE OR REPLACE FUNCTION docs_ut.test_doc_create()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id text;
  v_charte_id text;
  v_d record;
  v_page_cnt int;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);
  DELETE FROM docs.document WHERE tenant_id = 'test';
  DELETE FROM docs.charte WHERE tenant_id = 'test';

  -- A4 portrait
  v_id := docs.doc_create('Test A4');
  SELECT * INTO v_d FROM docs.document WHERE id = v_id;
  RETURN NEXT is(v_d.width, 210::numeric, 'A4 width = 210');
  RETURN NEXT is(v_d.height, 297::numeric, 'A4 height = 297');
  RETURN NEXT is(v_d.format, 'A4', 'format stored');
  RETURN NEXT is(v_d.orientation, 'portrait', 'orientation default portrait');

  -- First page created
  SELECT count(*)::int INTO v_page_cnt FROM docs.page WHERE doc_id = v_id;
  RETURN NEXT is(v_page_cnt, 1, 'first page auto-created');

  -- A3 landscape (swap)
  v_id := docs.doc_create('Test A3 L', p_format := 'A3', p_orientation := 'landscape');
  SELECT * INTO v_d FROM docs.document WHERE id = v_id;
  RETURN NEXT is(v_d.width, 420::numeric, 'A3 landscape width = 420');
  RETURN NEXT is(v_d.height, 297::numeric, 'A3 landscape height = 297');

  -- HD (no swap for screen)
  v_id := docs.doc_create('Test HD', p_format := 'HD');
  SELECT * INTO v_d FROM docs.document WHERE id = v_id;
  RETURN NEXT is(v_d.width, 1920::numeric, 'HD width = 1920');
  RETURN NEXT is(v_d.height, 1080::numeric, 'HD height = 1080');

  -- With charte
  v_charte_id := docs.charte_create(p_name := 'Test DC', p_color_bg := '#fff', p_color_main := '#000',
    p_color_accent := '#f00', p_color_text := '#333', p_color_text_light := '#888', p_color_border := '#eee',
    p_font_heading := 'Inter', p_font_body := 'Inter');
  v_id := docs.doc_create('With Charte', p_charte_id := v_charte_id);
  SELECT * INTO v_d FROM docs.document WHERE id = v_id;
  RETURN NEXT is(v_d.charte_id, v_charte_id, 'charte linked');

  -- With initial HTML
  v_id := docs.doc_create('With HTML', p_html := '<div data-id="h1">Hello</div>');
  RETURN NEXT is(
    (SELECT html FROM docs.page WHERE doc_id = v_id AND page_index = 0),
    '<div data-id="h1">Hello</div>', 'initial HTML stored');

  DELETE FROM docs.document WHERE tenant_id = 'test';
  DELETE FROM docs.charte WHERE tenant_id = 'test';
END;
$function$;
