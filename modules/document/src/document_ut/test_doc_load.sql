CREATE OR REPLACE FUNCTION document_ut.test_doc_load()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id text;
  v_charte_id text;
  v_result jsonb;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);
  DELETE FROM document.document WHERE tenant_id = 'test';
  DELETE FROM document.charte WHERE tenant_id = 'test';

  v_charte_id := document.charte_create(p_name := 'Load Charte', p_color_bg := '#FAF6F1', p_color_main := '#2C3E2D',
    p_color_accent := '#C4956A', p_color_text := '#333', p_color_text_light := '#888', p_color_border := '#eee',
    p_font_heading := 'Inter', p_font_body := 'Inter');

  v_id := document.doc_create('Load Test', p_charte_id := v_charte_id, p_html := '<p data-id="p1">Hi</p>');
  PERFORM document.page_add(v_id, 'Page 2', '<p data-id="p2">Page two</p>');

  v_result := document.doc_load(v_id);

  RETURN NEXT ok(v_result IS NOT NULL, 'doc_load returns data');
  RETURN NEXT is(v_result->>'name', 'Load Test', 'name');
  RETURN NEXT is(v_result->>'format', 'A4', 'format');
  RETURN NEXT is(jsonb_array_length(v_result->'pages'), 2, '2 pages loaded');
  RETURN NEXT is((v_result->'pages'->0->>'page_index')::int, 0, 'page 0 index');
  RETURN NEXT is((v_result->'pages'->1->>'page_index')::int, 1, 'page 1 index');
  RETURN NEXT ok(v_result->>'charte_css' LIKE '%--charte-color-bg%', 'charte CSS included');

  -- Not found
  RETURN NEXT ok(document.doc_load('nonexistent') IS NULL, 'NULL for unknown doc');

  DELETE FROM document.document WHERE tenant_id = 'test';
  DELETE FROM document.charte WHERE tenant_id = 'test';
END;
$function$;
