CREATE OR REPLACE FUNCTION quote_ut.test_ligne_totals()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int;
  v_client_id int;
  v_ht numeric(12,2);
  v_tva numeric(12,2);
  v_ttc numeric(12,2);
BEGIN
  DELETE FROM quote.ligne;
  DELETE FROM quote.facture;
  DELETE FROM quote.devis;

  SELECT id INTO v_client_id FROM crm.client LIMIT 1;

  PERFORM quote.post_devis_save(jsonb_build_object('client_id', v_client_id, 'objet', 'Test totaux'));
  SELECT id INTO v_id FROM quote.devis ORDER BY id DESC LIMIT 1;

  -- 3h à 45.50 EUR, TVA 10%
  PERFORM quote.post_ligne_ajouter(jsonb_build_object(
    'devis_id', v_id, 'description', 'Main oeuvre',
    'quantite', 3, 'unite', 'h', 'prix_unitaire', 45.50, 'tva_rate', 10
  ));
  -- 2.5 m2 à 35 EUR, TVA 20%
  PERFORM quote.post_ligne_ajouter(jsonb_build_object(
    'devis_id', v_id, 'description', 'Carrelage',
    'quantite', 2.5, 'unite', 'm2', 'prix_unitaire', 35, 'tva_rate', 20
  ));

  -- Calculer via SQL direct (arrondi par ligne)
  SELECT sum(round(quantite * prix_unitaire, 2)) INTO v_ht
    FROM quote.ligne WHERE devis_id = v_id;
  SELECT sum(round(quantite * prix_unitaire * tva_rate / 100, 2)) INTO v_tva
    FROM quote.ligne WHERE devis_id = v_id;
  v_ttc := v_ht + v_tva;

  -- HT: round(3*45.50, 2) + round(2.5*35, 2) = 136.50 + 87.50 = 224.00
  RETURN NEXT is(v_ht, 224.00::numeric(12,2), 'Total HT = 224.00');

  -- TVA: round(3*45.50*10/100, 2) + round(2.5*35*20/100, 2) = 13.65 + 17.50 = 31.15
  RETURN NEXT is(v_tva, 31.15::numeric(12,2), 'Total TVA = 31.15 (arrondi par ligne)');

  -- TTC = HT + TVA
  RETURN NEXT is(v_ttc, 255.15::numeric(12,2), 'Total TTC = 255.15');

  DELETE FROM quote.ligne;
  DELETE FROM quote.devis;
END;
$function$;
