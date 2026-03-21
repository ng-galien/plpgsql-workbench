CREATE OR REPLACE FUNCTION docs_ut.test_charte_delete()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_c docs.charte;
  v_cnt int;
  v_ok boolean;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);
  DELETE FROM docs.document WHERE tenant_id = 'test';
  DELETE FROM docs.charte WHERE tenant_id = 'test';

  v_c := docs.charte_create(jsonb_populate_record(NULL::docs.charte, jsonb_build_object(
    'name', 'To Delete', 'color_bg', '#fff', 'color_main', '#000', 'color_accent', '#f00',
    'color_text', '#333', 'color_text_light', '#888', 'color_border', '#eee',
    'font_heading', 'Inter', 'font_body', 'Inter'
  )));

  INSERT INTO docs.document (name, charte_id, category) VALUES ('Linked Doc', v_c.id, 'general');

  v_ok := docs.charte_delete(v_c.id);
  RETURN NEXT ok(v_ok, 'charte_delete returns true');

  SELECT count(*)::int INTO v_cnt FROM docs.charte WHERE id = v_c.id;
  RETURN NEXT is(v_cnt, 0, 'charte removed');

  SELECT count(*)::int INTO v_cnt FROM docs.document WHERE name = 'Linked Doc' AND tenant_id = 'test';
  RETURN NEXT is(v_cnt, 1, 'linked document still exists');
  RETURN NEXT ok(
    (SELECT charte_id IS NULL FROM docs.document WHERE name = 'Linked Doc' AND tenant_id = 'test'),
    'charte_id set to NULL on document'
  );

  v_ok := docs.charte_delete('nonexistent-id');
  RETURN NEXT ok(NOT v_ok, 'returns false for unknown charte');

  DELETE FROM docs.document WHERE tenant_id = 'test';
  DELETE FROM docs.charte WHERE tenant_id = 'test';
END;
$function$;
