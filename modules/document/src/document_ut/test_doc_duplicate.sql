CREATE OR REPLACE FUNCTION document_ut.test_doc_duplicate()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_src text;
  v_dup text;
  v_src_pages int;
  v_dup_pages int;
  v_dup_html text;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);
  DELETE FROM document.document WHERE tenant_id = 'test';

  v_src := document.doc_create('Original', p_html := '<div data-id="h">Hello</div>');
  PERFORM document.page_add(v_src, 'P2', '<p>Page 2</p>');

  v_dup := document.doc_duplicate(v_src, 'Copy');

  RETURN NEXT ok(v_dup IS NOT NULL, 'duplicate returns new id');
  RETURN NEXT ok(v_dup != v_src, 'different id');
  RETURN NEXT is(
    (SELECT name FROM document.document WHERE id = v_dup), 'Copy', 'new name');
  RETURN NEXT is(
    (SELECT format FROM document.document WHERE id = v_dup), 'A4', 'format copied');

  SELECT count(*)::int INTO v_src_pages FROM document.page WHERE doc_id = v_src;
  SELECT count(*)::int INTO v_dup_pages FROM document.page WHERE doc_id = v_dup;
  RETURN NEXT is(v_dup_pages, v_src_pages, 'same page count');

  SELECT html INTO v_dup_html FROM document.page WHERE doc_id = v_dup AND page_index = 0;
  RETURN NEXT is(v_dup_html, '<div data-id="h">Hello</div>', 'HTML cloned');

  DELETE FROM document.document WHERE tenant_id = 'test';
END;
$function$;
