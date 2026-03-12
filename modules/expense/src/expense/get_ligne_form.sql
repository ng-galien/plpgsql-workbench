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
    RETURN pgv.error('400', 'note_id requis');
  END IF;

  -- Build category options
  SELECT jsonb_agg(jsonb_build_object('value', id::text, 'label', nom) ORDER BY nom)
    INTO v_cat_options
    FROM expense.categorie;

  v_cat_options := coalesce(v_cat_options, '[]'::jsonb);

  v_body := '<form data-rpc="post_ligne_ajouter">'
    || '<input type="hidden" name="note_id" value="' || v_note_id || '">'
    || pgv.input('date_depense', 'date', 'Date', to_char(now()::date, 'YYYY-MM-DD'), true)
    || pgv.sel('categorie_id', 'Catégorie', v_cat_options)
    || pgv.input('description', 'text', 'Description', NULL, true)
    || '<div class="pgv-grid">'
    || pgv.input('montant_ht', 'number', 'Montant HT', NULL, true)
    || pgv.input('tva', 'number', 'TVA', '0')
    || pgv.input('km', 'number', 'Km (si déplacement)')
    || '</div>'
    || '<button type="submit">Ajouter la ligne</button>'
    || '</form>';

  RETURN v_body;
END;
$function$;
