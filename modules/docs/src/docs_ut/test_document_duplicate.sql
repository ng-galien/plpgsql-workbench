CREATE OR REPLACE FUNCTION docs_ut.test_document_duplicate()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_d docs.document;
  v_dup text;
  v_src_pages int;
  v_dup_pages int;
  v_dup_html text;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);
  DELETE FROM docs.document WHERE tenant_id = 'test';

  v_d := docs.document_create(jsonb_populate_record(NULL::docs.document, '{"name":"Original"}'::jsonb));
  PERFORM docs.page_set_html(v_d.id, 0, '<div data-id="h">Hello</div>');
  PERFORM docs.page_add(v_d.id, 'P2', '<p>Page 2</p>');

  v_dup := docs.document_duplicate(v_d.id, 'Copy');

  RETURN NEXT ok(v_dup IS NOT NULL, 'duplicate returns new id');
  RETURN NEXT ok(v_dup != v_d.id, 'different id');
  RETURN NEXT is(
    (SELECT name FROM docs.document WHERE id = v_dup), 'Copy', 'new name');
  RETURN NEXT is(
    (SELECT format FROM docs.document WHERE id = v_dup), 'A4', 'format copied');

  SELECT count(*)::int INTO v_src_pages FROM docs.page WHERE doc_id = v_d.id;
  SELECT count(*)::int INTO v_dup_pages FROM docs.page WHERE doc_id = v_dup;
  RETURN NEXT is(v_dup_pages, v_src_pages, 'same page count');

  SELECT html INTO v_dup_html FROM docs.page WHERE doc_id = v_dup AND page_index = 0;
  RETURN NEXT is(v_dup_html, '<div data-id="h">Hello</div>', 'HTML cloned');

  DELETE FROM docs.document WHERE tenant_id = 'test';
END;
$function$;
