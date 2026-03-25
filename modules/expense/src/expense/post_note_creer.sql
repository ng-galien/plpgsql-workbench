CREATE OR REPLACE FUNCTION expense.post_note_creer(p_params jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_id int := (p_params->>'id')::int;
  v_auteur text := p_params->>'auteur';
  v_date_debut date := (p_params->>'date_debut')::date;
  v_date_fin date := (p_params->>'date_fin')::date;
  v_commentaire text := p_params->>'commentaire';
  v_note_id int;
BEGIN
  IF v_auteur IS NULL OR v_date_debut IS NULL OR v_date_fin IS NULL THEN
    RETURN pgv.toast(pgv.t('expense.err_fields_requis'), 'error');
  END IF;

  IF v_date_fin < v_date_debut THEN
    RETURN pgv.toast(pgv.t('expense.err_date_order'), 'error');
  END IF;

  IF v_id IS NOT NULL THEN
    UPDATE expense.note
       SET auteur = v_auteur,
           date_debut = v_date_debut,
           date_fin = v_date_fin,
           commentaire = v_commentaire,
           updated_at = now()
     WHERE id = v_id AND statut = 'brouillon';

    IF NOT FOUND THEN
      RETURN pgv.toast(pgv.t('expense.err_note_or_modifiable'), 'error');
    END IF;
    v_note_id := v_id;
  ELSE
    INSERT INTO expense.note (reference, auteur, date_debut, date_fin, commentaire)
    VALUES (expense._next_numero(), v_auteur, v_date_debut, v_date_fin, v_commentaire)
    RETURNING id INTO v_note_id;
  END IF;

  RETURN pgv.toast(CASE WHEN v_id IS NOT NULL THEN pgv.t('expense.toast_note_modifiee') ELSE pgv.t('expense.toast_note_creee') END)
    || pgv.redirect('/note?p_id=' || v_note_id);
END;
$function$;
