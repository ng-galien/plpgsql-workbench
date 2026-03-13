CREATE OR REPLACE FUNCTION expense.get_note_form(p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int := (p_params->>'id')::int;
  v_note record;
  v_body text;
BEGIN
  IF v_id IS NOT NULL THEN
    SELECT * INTO v_note FROM expense.note WHERE id = v_id;
    IF NOT FOUND THEN
      RETURN pgv.error('404', pgv.t('expense.err_not_found'));
    END IF;
    IF v_note.statut <> 'brouillon' THEN
      RETURN pgv.error('400', pgv.t('expense.err_not_modifiable'), pgv.t('expense.err_not_modifiable_detail'));
    END IF;
  END IF;

  v_body := '';

  IF v_id IS NOT NULL THEN
    v_body := v_body || '<input type="hidden" name="id" value="' || v_id || '">';
  END IF;

  v_body := v_body
    || pgv.input('auteur', 'text', pgv.t('expense.field_auteur'), v_note.auteur, true)
    || '<div class="pgv-grid">'
    || pgv.input('date_debut', 'date', pgv.t('expense.field_date_debut'), CASE WHEN v_note IS NOT NULL THEN to_char(v_note.date_debut, 'YYYY-MM-DD') ELSE to_char(date_trunc('month', now()), 'YYYY-MM-DD') END, true)
    || pgv.input('date_fin', 'date', pgv.t('expense.field_date_fin'), CASE WHEN v_note IS NOT NULL THEN to_char(v_note.date_fin, 'YYYY-MM-DD') ELSE to_char(now()::date, 'YYYY-MM-DD') END, true)
    || '</div>'
    || pgv.textarea('commentaire', pgv.t('expense.field_commentaire'), v_note.commentaire);

  RETURN pgv.form('post_note_creer', v_body, CASE WHEN v_id IS NOT NULL THEN pgv.t('expense.btn_modifier') ELSE pgv.t('expense.btn_creer_note') END);
END;
$function$;
