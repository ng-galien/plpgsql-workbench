CREATE OR REPLACE FUNCTION purchase.post_reception_creer(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_commande_id int := (p_data->>'p_commande_id')::int;
  v_statut text;
  v_reception_id int;
  v_numero text;
  v_nb_lignes int := 0;
  v_all_received bool;
  r record;
BEGIN
  SELECT statut INTO v_statut FROM purchase.commande WHERE id = v_commande_id;
  IF v_statut NOT IN ('envoyee', 'partiellement_recue') THEN
    RETURN pgv.toast(pgv.t('purchase.err_not_receivable'), 'error');
  END IF;

  v_numero := purchase._next_numero('REC');
  INSERT INTO purchase.reception (commande_id, numero, notes)
  VALUES (v_commande_id, v_numero, coalesce(p_data->>'p_notes', ''))
  RETURNING id INTO v_reception_id;

  -- Réceptionner toutes les quantités restantes
  FOR r IN
    SELECT l.id AS ligne_id, purchase._quantite_restante(l.id) AS restante
      FROM purchase.ligne l
     WHERE l.commande_id = v_commande_id
       AND purchase._quantite_restante(l.id) > 0
  LOOP
    INSERT INTO purchase.reception_ligne (reception_id, ligne_id, quantite_recue)
    VALUES (v_reception_id, r.ligne_id, r.restante);
    v_nb_lignes := v_nb_lignes + 1;
  END LOOP;

  IF v_nb_lignes = 0 THEN
    -- Rien à réceptionner, rollback reception
    DELETE FROM purchase.reception WHERE id = v_reception_id;
    RETURN pgv.toast(pgv.t('purchase.err_all_received'), 'error');
  END IF;

  -- Vérifier si tout est reçu
  SELECT NOT exists(
    SELECT 1 FROM purchase.ligne l
     WHERE l.commande_id = v_commande_id
       AND purchase._quantite_restante(l.id) > 0
  ) INTO v_all_received;

  IF v_all_received THEN
    UPDATE purchase.commande SET statut = 'recue' WHERE id = v_commande_id;
  ELSE
    UPDATE purchase.commande SET statut = 'partiellement_recue' WHERE id = v_commande_id;
  END IF;

  RETURN pgv.toast(format('Réception %s créée (%s %s)', v_numero, v_nb_lignes, pgv.t('purchase.col_lignes')))
    || pgv.redirect(pgv.call_ref('get_commande', jsonb_build_object('p_id', v_commande_id)));
END;
$function$;
