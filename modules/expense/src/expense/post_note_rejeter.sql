CREATE OR REPLACE FUNCTION expense.post_note_rejeter(p_params jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int := (p_params->>'id')::int;
BEGIN
  IF v_id IS NULL THEN
    RETURN pgv.toast(pgv.t('expense.err_id_requis'), 'error');
  END IF;

  UPDATE expense.note SET statut = 'rejetee', updated_at = now()
   WHERE id = v_id AND statut = 'soumise';

  IF NOT FOUND THEN
    RETURN pgv.toast(pgv.t('expense.err_not_soumise'), 'error');
  END IF;

  RETURN pgv.toast(pgv.t('expense.toast_note_rejetee'))
    || pgv.redirect('/note?p_id=' || v_id);
END;
$function$;
