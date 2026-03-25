CREATE OR REPLACE FUNCTION expense.post_note_soumettre(p_params jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_id int := (p_params->>'id')::int;
  v_nb_lignes int;
BEGIN
  IF v_id IS NULL THEN
    RETURN pgv.toast(pgv.t('expense.err_id_requis'), 'error');
  END IF;

  SELECT count(*)::int INTO v_nb_lignes FROM expense.ligne WHERE note_id = v_id;
  IF v_nb_lignes = 0 THEN
    RETURN pgv.toast(pgv.t('expense.err_no_ligne'), 'error');
  END IF;

  UPDATE expense.note SET statut = 'soumise', updated_at = now()
   WHERE id = v_id AND statut = 'brouillon';

  IF NOT FOUND THEN
    RETURN pgv.toast(pgv.t('expense.err_not_brouillon_submit'), 'error');
  END IF;

  RETURN pgv.toast(pgv.t('expense.toast_note_soumise'))
    || pgv.redirect('/note?p_id=' || v_id);
END;
$function$;
