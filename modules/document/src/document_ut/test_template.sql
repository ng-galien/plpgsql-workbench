CREATE OR REPLACE FUNCTION document_ut.test_template()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id1 uuid;
  v_id2 uuid;
  v_row document.template;
  v_cnt int;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);

  -- Insert templates
  INSERT INTO document.template (name, doc_type, format, is_default)
  VALUES ('Facture standard', 'facture', 'A4', true)
  RETURNING id INTO v_id1;

  INSERT INTO document.template (name, doc_type, format)
  VALUES ('Devis premium', 'devis', 'A4')
  RETURNING id INTO v_id2;

  -- List all
  SELECT count(*)::int INTO v_cnt FROM document.list_templates();
  RETURN NEXT ok(v_cnt >= 2, 'list_templates returns at least 2');

  -- List by type
  SELECT count(*)::int INTO v_cnt FROM document.list_templates('facture');
  RETURN NEXT ok(v_cnt >= 1, 'list_templates filters by doc_type');

  -- Get by ID
  v_row := document.get_template(v_id1);
  RETURN NEXT is(v_row.name, 'Facture standard', 'get_template returns correct name');
  RETURN NEXT ok(v_row.is_default, 'is_default true');

  -- Cleanup
  DELETE FROM document.template WHERE id IN (v_id1, v_id2);
END;
$function$;
