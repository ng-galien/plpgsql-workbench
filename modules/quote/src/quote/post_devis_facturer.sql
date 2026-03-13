CREATE OR REPLACE FUNCTION quote.post_devis_facturer(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_devis_id int := (p_data->>'id')::int;
  v_facture_id int;
  v_numero text;
  d record;
BEGIN
  SELECT * INTO d FROM quote.devis WHERE id = v_devis_id;
  IF NOT FOUND THEN RAISE EXCEPTION '%', pgv.t('quote.err_not_found_devis'); END IF;
  IF d.statut <> 'accepte' THEN RAISE EXCEPTION '%', pgv.t('quote.err_accepted_only'); END IF;

  v_numero := quote._next_numero('FAC');

  INSERT INTO quote.facture (numero, client_id, devis_id, objet, notes)
  VALUES (v_numero, d.client_id, v_devis_id, d.objet, d.notes)
  RETURNING id INTO v_facture_id;

  INSERT INTO quote.ligne (facture_id, sort_order, description, quantite, unite, prix_unitaire, tva_rate)
  SELECT v_facture_id, sort_order, description, quantite, unite, prix_unitaire, tva_rate
    FROM quote.ligne WHERE devis_id = v_devis_id
   ORDER BY sort_order, id;

  RETURN pgv.toast(pgv.t('quote.toast_facture_created') || ' ' || v_numero)
    || pgv.redirect(pgv.call_ref('get_facture', jsonb_build_object('p_id', v_facture_id)));
END;
$function$;
