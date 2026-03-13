CREATE OR REPLACE FUNCTION expense._note_form_body()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN pgv.input('auteur', 'text', pgv.t('expense.field_auteur'), NULL, true)
    || '<div class="pgv-grid">'
    || pgv.input('date_debut', 'date', pgv.t('expense.field_date_debut'), to_char(date_trunc('month', now()), 'YYYY-MM-DD'), true)
    || pgv.input('date_fin', 'date', pgv.t('expense.field_date_fin'), to_char(now()::date, 'YYYY-MM-DD'), true)
    || '</div>'
    || pgv.textarea('commentaire', pgv.t('expense.field_commentaire'));
END;
$function$;
