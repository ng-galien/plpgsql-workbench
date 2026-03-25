CREATE OR REPLACE FUNCTION expense.post_ligne_ajouter(p_params jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_note_id int := (p_params->>'note_id')::int;
  v_date date := (p_params->>'date_depense')::date;
  v_categorie_id int := (p_params->>'categorie_id')::int;
  v_description text := p_params->>'description';
  v_montant_ht numeric(12,2) := (p_params->>'montant_ht')::numeric;
  v_tva numeric(12,2) := coalesce((p_params->>'tva')::numeric, 0);
  v_km numeric(8,1) := (p_params->>'km')::numeric;
  v_statut text;
BEGIN
  IF v_note_id IS NULL OR v_date IS NULL OR v_description IS NULL OR v_montant_ht IS NULL THEN
    RETURN pgv.toast(pgv.t('expense.err_ligne_fields'), 'error');
  END IF;

  SELECT statut INTO v_statut FROM expense.note WHERE id = v_note_id;
  IF NOT FOUND THEN
    RETURN pgv.toast(pgv.t('expense.err_ligne_not_found'), 'error');
  END IF;
  IF v_statut <> 'brouillon' THEN
    RETURN pgv.toast(pgv.t('expense.err_not_brouillon'), 'error');
  END IF;

  INSERT INTO expense.ligne (note_id, date_depense, categorie_id, description, montant_ht, tva, km)
  VALUES (v_note_id, v_date, v_categorie_id, v_description, v_montant_ht, v_tva, v_km);

  RETURN pgv.toast(pgv.t('expense.toast_ligne_ajoutee'))
    || pgv.redirect('/note?p_id=' || v_note_id);
END;
$function$;
