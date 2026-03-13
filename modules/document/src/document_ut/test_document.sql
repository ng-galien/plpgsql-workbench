CREATE OR REPLACE FUNCTION document_ut.test_document()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_tpl_id uuid;
  v_doc_id1 uuid;
  v_doc_id2 uuid;
  v_cnt int;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);

  -- Setup template
  INSERT INTO document.template (name, doc_type) VALUES ('TPL test', 'facture')
  RETURNING id INTO v_tpl_id;

  -- Insert documents
  INSERT INTO document.document (template_id, doc_type, ref_module, ref_id, title, status)
  VALUES (v_tpl_id, 'facture', 'quote', '42', 'Facture #001', 'draft')
  RETURNING id INTO v_doc_id1;

  INSERT INTO document.document (template_id, doc_type, ref_module, ref_id, title, status)
  VALUES (v_tpl_id, 'devis', 'quote', '43', 'Devis #010', 'generated')
  RETURNING id INTO v_doc_id2;

  -- List all
  SELECT count(*)::int INTO v_cnt FROM document.list_documents();
  RETURN NEXT ok(v_cnt >= 2, 'list_documents returns at least 2');

  -- Filter by type
  SELECT count(*)::int INTO v_cnt FROM document.list_documents('{"doc_type":"facture"}');
  RETURN NEXT ok(v_cnt >= 1, 'filter by doc_type works');

  -- Filter by status
  SELECT count(*)::int INTO v_cnt FROM document.list_documents('{"status":"generated"}');
  RETURN NEXT ok(v_cnt >= 1, 'filter by status works');

  -- Filter by module
  SELECT count(*)::int INTO v_cnt FROM document.list_documents('{"ref_module":"quote"}');
  RETURN NEXT ok(v_cnt >= 2, 'filter by ref_module works');

  -- Cleanup
  DELETE FROM document.document WHERE id IN (v_doc_id1, v_doc_id2);
  DELETE FROM document.template WHERE id = v_tpl_id;
END;
$function$;
