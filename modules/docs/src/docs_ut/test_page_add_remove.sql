CREATE OR REPLACE FUNCTION docs_ut.test_page_add_remove()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id text;
  v_idx int;
  v_cnt int;
  v_names text[];
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);
  DELETE FROM docs.document WHERE tenant_id = 'test';

  v_id := docs.doc_create('Pages Test');

  -- Add pages
  v_idx := docs.page_add(v_id, 'Page 2');
  RETURN NEXT is(v_idx, 1, 'page_add returns index 1');

  v_idx := docs.page_add(v_id, 'Page 3');
  RETURN NEXT is(v_idx, 2, 'page_add returns index 2');

  SELECT count(*)::int INTO v_cnt FROM docs.page WHERE doc_id = v_id;
  RETURN NEXT is(v_cnt, 3, '3 pages total');

  -- Remove middle page (index 1)
  RETURN NEXT ok(docs.page_remove(v_id, 1), 'remove page 1');

  SELECT count(*)::int INTO v_cnt FROM docs.page WHERE doc_id = v_id;
  RETURN NEXT is(v_cnt, 2, '2 pages after remove');

  -- Check renumbering: remaining pages should be 0, 1
  SELECT array_agg(name ORDER BY page_index) INTO v_names FROM docs.page WHERE doc_id = v_id;
  RETURN NEXT is(v_names, ARRAY['Page 1', 'Page 3'], 'pages renumbered correctly');

  -- Remove until 1 page left
  PERFORM docs.page_remove(v_id, 1);
  -- Try to remove the last page
  BEGIN
    PERFORM docs.page_remove(v_id, 0);
    RETURN NEXT fail('should raise on last page');
  EXCEPTION WHEN OTHERS THEN
    RETURN NEXT pass('raises on last page removal');
  END;

  DELETE FROM docs.document WHERE tenant_id = 'test';
END;
$function$;
