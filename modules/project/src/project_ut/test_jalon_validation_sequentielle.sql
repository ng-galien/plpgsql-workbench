CREATE OR REPLACE FUNCTION project_ut.test_jalon_validation_sequentielle()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_cid int;
  v_j1 int;
  v_j2 int;
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);

  -- Create chantier + 2 jalons
  INSERT INTO project.chantier (numero, client_id, objet, statut)
  VALUES ('CHT-TEST-SEQ', (SELECT id FROM crm.client LIMIT 1), 'Test séquentiel', 'execution')
  RETURNING id INTO v_cid;

  INSERT INTO project.jalon (chantier_id, sort_order, label) VALUES (v_cid, 1, 'Jalon 1') RETURNING id INTO v_j1;
  INSERT INTO project.jalon (chantier_id, sort_order, label) VALUES (v_cid, 2, 'Jalon 2') RETURNING id INTO v_j2;

  -- Validate jalon 2 should fail (jalon 1 not validated)
  RETURN NEXT throws_ok(
    format('SELECT project.post_jalon_valider(%s)', v_j2),
    pgv.t('project.err_jalons_precedents'),
    'cannot validate jalon 2 before jalon 1'
  );

  -- Validate jalon 1 should succeed
  PERFORM project.post_jalon_valider(v_j1);
  RETURN NEXT is(
    (SELECT statut FROM project.jalon WHERE id = v_j1),
    'valide',
    'jalon 1 validated'
  );

  -- Now validate jalon 2 should succeed
  PERFORM project.post_jalon_valider(v_j2);
  RETURN NEXT is(
    (SELECT statut FROM project.jalon WHERE id = v_j2),
    'valide',
    'jalon 2 validated after jalon 1'
  );

  -- Cleanup
  DELETE FROM project.chantier WHERE id = v_cid;
END;
$function$;
