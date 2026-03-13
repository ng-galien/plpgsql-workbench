CREATE OR REPLACE FUNCTION expense.get_ligne_form(p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_note_id int := (p_params->>'note_id')::int;
  v_cat_options jsonb;
  v_body text;
BEGIN
  IF v_note_id IS NULL THEN
    RETURN pgv.error('400', pgv.t('expense.err_note_id_requis'));
  END IF;

  SELECT jsonb_agg(jsonb_build_object('value', id::text, 'label', nom) ORDER BY nom)
    INTO v_cat_options
    FROM expense.categorie;

  v_cat_options := coalesce(v_cat_options, '[]'::jsonb);

  v_body := '<input type="hidden" name="note_id" value="' || v_note_id || '">'
    || pgv.input('date_depense', 'date', pgv.t('expense.field_date_depense'), to_char(now()::date, 'YYYY-MM-DD'), true)
    || pgv.sel('categorie_id', pgv.t('expense.field_categorie'), v_cat_options)
    || pgv.input('description', 'text', pgv.t('expense.field_description'), NULL, true)
    || '<div class="pgv-grid">'
    || pgv.input('montant_ht', 'number', pgv.t('expense.field_montant_ht'), NULL, true)
    || pgv.input('tva', 'number', pgv.t('expense.field_tva'), '0')
    || pgv.input('km', 'number', pgv.t('expense.field_km'))
    || '</div>';

  RETURN pgv.form('post_ligne_ajouter', v_body, pgv.t('expense.btn_ajouter_ligne'));
END;
$function$;
