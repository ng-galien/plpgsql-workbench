CREATE OR REPLACE FUNCTION docs_ut.test_charte_delete()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id text;
  v_cnt int;
  v_ok boolean;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);
  DELETE FROM docs.document WHERE tenant_id = 'test';
  DELETE FROM docs.charte WHERE tenant_id = 'test';

  v_id := docs.charte_create(p_name := 'To Delete', p_color_bg := '#fff', p_color_main := '#000',
    p_color_accent := '#f00', p_color_text := '#333', p_color_text_light := '#888', p_color_border := '#eee',
    p_font_heading := 'Inter', p_font_body := 'Inter');

  -- Create a doc linked to this charte
  INSERT INTO docs.document (name, charte_id, category) VALUES ('Linked Doc', v_id, 'general');

  v_ok := docs.charte_delete('To Delete');
  RETURN NEXT ok(v_ok, 'charte_delete returns true');

  SELECT count(*)::int INTO v_cnt FROM docs.charte WHERE id = v_id;
  RETURN NEXT is(v_cnt, 0, 'charte removed');

  -- Document still exists but charte_id is NULL (FK SET NULL)
  SELECT count(*)::int INTO v_cnt FROM docs.document WHERE name = 'Linked Doc' AND tenant_id = 'test';
  RETURN NEXT is(v_cnt, 1, 'linked document still exists');
  RETURN NEXT ok(
    (SELECT charte_id IS NULL FROM docs.document WHERE name = 'Linked Doc' AND tenant_id = 'test'),
    'charte_id set to NULL on document'
  );

  -- Delete nonexistent
  v_ok := docs.charte_delete('Nonexistent');
  RETURN NEXT ok(NOT v_ok, 'returns false for unknown charte');

  DELETE FROM docs.document WHERE tenant_id = 'test';
  DELETE FROM docs.charte WHERE tenant_id = 'test';
END;
$function$;
