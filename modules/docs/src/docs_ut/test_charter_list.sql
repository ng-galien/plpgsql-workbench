CREATE OR REPLACE FUNCTION docs_ut.test_charter_list()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE v_cnt int; v_first jsonb;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);
  DELETE FROM docs.charter WHERE tenant_id = 'test';
  PERFORM docs.charter_create(jsonb_populate_record(NULL::docs.charter, jsonb_build_object(
    'name', 'List A', 'color_bg', '#fff', 'color_main', '#000', 'color_accent', '#f00',
    'color_text', '#333', 'color_text_light', '#888', 'color_border', '#eee',
    'font_heading', 'Inter', 'font_body', 'Inter')));
  PERFORM docs.charter_create(jsonb_populate_record(NULL::docs.charter, jsonb_build_object(
    'name', 'List B', 'color_bg', '#eee', 'color_main', '#111', 'color_accent', '#0f0',
    'color_text', '#222', 'color_text_light', '#777', 'color_border', '#ddd',
    'font_heading', 'Oswald', 'font_body', 'Lato')));
  SELECT count(*)::int INTO v_cnt FROM docs.charter_list();
  RETURN NEXT is(v_cnt, 2, '2 charters listed');
  SELECT * INTO v_first FROM docs.charter_list() LIMIT 1;
  RETURN NEXT is(v_first->>'name', 'List A', 'first sorted by name');
  RETURN NEXT ok(v_first->>'color_bg' IS NOT NULL, 'color_bg present');
  RETURN NEXT ok(v_first->>'font_heading' IS NOT NULL, 'font_heading present');
  DELETE FROM docs.charter WHERE tenant_id = 'test';
END;
$function$;
