CREATE OR REPLACE FUNCTION quote.post_devis_dupliquer(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_src_id int := (p_data->>'id')::int;
  v_new_id int;
  v_numero text;
  d record;
BEGIN
  SELECT * INTO d FROM quote.devis WHERE id = v_src_id;
  IF NOT FOUND THEN RAISE EXCEPTION '%', pgv.t('quote.err_not_found_devis'); END IF;

  v_numero := quote._next_numero('DEV');

  INSERT INTO quote.devis (numero, client_id, objet, validite_jours, notes)
  VALUES (v_numero, d.client_id, d.objet, d.validite_jours, d.notes)
  RETURNING id INTO v_new_id;

  INSERT INTO quote.ligne (devis_id, sort_order, description, quantite, unite, prix_unitaire, tva_rate)
  SELECT v_new_id, sort_order, description, quantite, unite, prix_unitaire, tva_rate
    FROM quote.ligne WHERE devis_id = v_src_id
   ORDER BY sort_order, id;

  RETURN pgv.toast(pgv.t('quote.toast_devis_duplicated') || ' : ' || v_numero)
    || pgv.redirect(pgv.call_ref('get_devis', jsonb_build_object('p_id', v_new_id)));
END;
$function$;
