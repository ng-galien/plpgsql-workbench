CREATE OR REPLACE FUNCTION quote_ut.test_post_facture_relancer()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_client_id int;
  v_fac_id int;
  v_result text;
BEGIN
  -- cleanup
  UPDATE project.chantier SET devis_id = NULL WHERE devis_id IS NOT NULL;
  DELETE FROM quote.ligne;
  DELETE FROM quote.facture;
  DELETE FROM quote.devis;

  -- use existing client
  SELECT id INTO v_client_id FROM crm.client LIMIT 1;

  -- setup: facture envoyee created 45 days ago
  INSERT INTO quote.facture (numero, client_id, objet, statut, created_at)
    VALUES ('FAC-2099-001', v_client_id, 'Facture test', 'envoyee', now() - interval '45 days')
    RETURNING id INTO v_fac_id;

  -- relance succeeds
  v_result := quote.post_facture_relancer(jsonb_build_object('p_id', v_fac_id));
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'relance returns success toast');

  -- statut changed to relance
  RETURN NEXT is(
    (SELECT statut FROM quote.facture WHERE id = v_fac_id),
    'relance', 'statut changed to relance');

  -- notes updated
  RETURN NEXT ok(
    (SELECT notes FROM quote.facture WHERE id = v_fac_id) LIKE '%[Relance%',
    'notes contain relance entry');

  -- error: already relancee (not envoyee anymore)
  RETURN NEXT throws_ok(
    format('SELECT quote.post_facture_relancer(''{"p_id": %s}''::jsonb)', v_fac_id),
    'P0001', NULL, 'error on non-envoyee facture');

  -- error: brouillon facture
  UPDATE quote.facture SET statut = 'brouillon' WHERE id = v_fac_id;
  RETURN NEXT throws_ok(
    format('SELECT quote.post_facture_relancer(''{"p_id": %s}''::jsonb)', v_fac_id),
    'P0001', NULL, 'error on brouillon facture');

  -- error: facture too recent (< 30 days)
  UPDATE quote.facture SET statut = 'envoyee', created_at = now() - interval '10 days' WHERE id = v_fac_id;
  RETURN NEXT throws_ok(
    format('SELECT quote.post_facture_relancer(''{"p_id": %s}''::jsonb)', v_fac_id),
    'P0001', NULL, 'error on recent facture');

  -- error: missing facture
  RETURN NEXT throws_ok(
    'SELECT quote.post_facture_relancer(''{"p_id": 999999}''::jsonb)',
    'P0001', NULL, 'error on missing facture');

  -- cleanup
  DELETE FROM quote.ligne;
  DELETE FROM quote.facture;
  DELETE FROM quote.devis;
END;
$function$;
