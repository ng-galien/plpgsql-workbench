CREATE OR REPLACE FUNCTION document_ut.test_page_set_html()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id text;
  v_cnt int;
  v_rev_cnt int;
  v_html text;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);
  DELETE FROM document.document WHERE tenant_id = 'test';

  v_id := document.doc_create('HTML Test', p_html := '<div data-id="v1">Version 1</div>');

  -- Set new HTML
  v_cnt := document.page_set_html(v_id, 0, '<div data-id="v2">Version 2</div><span data-id="s1">Span</span>');
  RETURN NEXT is(v_cnt, 2, 'returns 2 data-id elements');

  -- Check HTML updated
  SELECT html INTO v_html FROM document.page WHERE doc_id = v_id AND page_index = 0;
  RETURN NEXT ok(v_html LIKE '%Version 2%', 'HTML updated');

  -- Check revision created
  SELECT count(*)::int INTO v_rev_cnt FROM document.page_revision WHERE doc_id = v_id AND page_index = 0;
  RETURN NEXT is(v_rev_cnt, 1, '1 revision saved');

  -- Check revision content
  RETURN NEXT is(
    (SELECT html FROM document.page_revision WHERE doc_id = v_id AND page_index = 0 AND version = 1),
    '<div data-id="v1">Version 1</div>', 'revision has old HTML');

  -- Second update
  v_cnt := document.page_set_html(v_id, 0, '<p data-id="v3">V3</p>');
  SELECT count(*)::int INTO v_rev_cnt FROM document.page_revision WHERE doc_id = v_id AND page_index = 0;
  RETURN NEXT is(v_rev_cnt, 2, '2 revisions after second update');

  DELETE FROM document.document WHERE tenant_id = 'test';
END;
$function$;
